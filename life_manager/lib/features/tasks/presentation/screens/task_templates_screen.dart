import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../../../data/models/task_template.dart';
import '../../../../data/models/category.dart';
import '../providers/template_providers.dart';
import '../providers/category_providers.dart';
import 'edit_template_screen.dart';
import 'template_report_screen.dart';

/// Filter options for templates
enum TemplateFilter {
  all,
  mostUsed,
  recent,
  highPriority,
  neverUsed,
}

/// Sort options for templates
enum TemplateSort {
  name,
  usageCount,
  lastUsed,
  priority,
}

/// Task Templates Management Screen
/// 
/// Shows all templates with horizontal category tabs and filters.
/// Allows creating, editing, and deleting templates.
class TaskTemplatesScreen extends ConsumerStatefulWidget {
  const TaskTemplatesScreen({super.key});

  @override
  ConsumerState<TaskTemplatesScreen> createState() => _TaskTemplatesScreenState();
}

class _TaskTemplatesScreenState extends ConsumerState<TaskTemplatesScreen> {
  String _searchQuery = '';
  bool _isSearching = false;
  String? _selectedCategoryId; // null = All
  TemplateFilter _activeFilter = TemplateFilter.all;
  TemplateSort _activeSort = TemplateSort.name;
  bool _sortDescending = true;
  final TextEditingController _searchController = TextEditingController();

  static const Color _accentColor = Color(0xFFCDAF56);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TaskTemplate> _applyFiltersAndSort(List<TaskTemplate> templates) {
    List<TaskTemplate> filtered = templates;

    // Apply category filter
    if (_selectedCategoryId != null) {
      filtered = filtered.where((t) => t.categoryId == _selectedCategoryId).toList();
    }

    // Apply filter
    switch (_activeFilter) {
      case TemplateFilter.all:
        break;
      case TemplateFilter.mostUsed:
        filtered = filtered.where((t) => t.usageCount > 0).toList();
        break;
      case TemplateFilter.recent:
        filtered = filtered.where((t) => t.lastUsedAt != null).toList();
        break;
      case TemplateFilter.highPriority:
        filtered = filtered.where((t) => t.priority.toLowerCase() == 'high').toList();
        break;
      case TemplateFilter.neverUsed:
        filtered = filtered.where((t) => t.usageCount == 0).toList();
        break;
    }

    // Apply sort
    filtered.sort((a, b) {
      int comparison;
      switch (_activeSort) {
        case TemplateSort.name:
          comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case TemplateSort.usageCount:
          comparison = a.usageCount.compareTo(b.usageCount);
          break;
        case TemplateSort.lastUsed:
          final aTime = a.lastUsedAt?.millisecondsSinceEpoch ?? 0;
          final bTime = b.lastUsedAt?.millisecondsSinceEpoch ?? 0;
          comparison = aTime.compareTo(bTime);
          break;
        case TemplateSort.priority:
          final priorityOrder = {'high': 3, 'medium': 2, 'low': 1};
          final aPriority = priorityOrder[a.priority.toLowerCase()] ?? 0;
          final bPriority = priorityOrder[b.priority.toLowerCase()] ?? 0;
          comparison = aPriority.compareTo(bPriority);
          break;
      }
      return _sortDescending ? -comparison : comparison;
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final templatesAsync = _searchQuery.isEmpty
        ? ref.watch(templateNotifierProvider)
        : ref.watch(templateSearchProvider(_searchQuery));
    final categoriesAsync = ref.watch(categoryNotifierProvider);

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(child: _buildContent(context, isDark, templatesAsync, categoriesAsync))
          : _buildContent(context, isDark, templatesAsync, categoriesAsync),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    AsyncValue<List<TaskTemplate>> templatesAsync,
    AsyncValue<List<Category>> categoriesAsync,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(isDark),
      body: templatesAsync.when(
        data: (templates) {
          return categoriesAsync.when(
            data: (categories) {
              final filteredTemplates = _applyFiltersAndSort(templates);
              return Column(
                children: [
                  // Category Tabs
                  _buildCategoryTabs(isDark, categories, templates),
                  
                  // Filter & Sort Bar
                  _buildFilterBar(isDark, templates),
                  
                  // Templates List
                  Expanded(
                    child: filteredTemplates.isEmpty
                        ? _buildEmptyState(context, isDark, templates.isEmpty)
                        : _buildTemplatesGrid(context, isDark, filteredTemplates, categories),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading categories: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading templates: $e')),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search templates...',
                hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            )
          : const Text('Task Templates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      actions: [
        if (_isSearching)
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 22),
            onPressed: () {
              setState(() {
                _isSearching = false;
                _searchQuery = '';
                _searchController.clear();
              });
            },
          )
        else ...[
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 22),
            onPressed: () => setState(() => _isSearching = true),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 22),
            onPressed: () => _showAdvancedFilters(context),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryTabs(bool isDark, List<Category> categories, List<TaskTemplate> allTemplates) {
    // Count templates per category
    final Map<String?, int> categoryCounts = {};
    for (final template in allTemplates) {
      categoryCounts[template.categoryId] = (categoryCounts[template.categoryId] ?? 0) + 1;
    }

    // Get unique category IDs from templates
    final usedCategoryIds = categoryCounts.keys.where((id) => id != null).toSet();
    final usedCategories = categories.where((c) => usedCategoryIds.contains(c.id)).toList();

    return Container(
      height: 56,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          // All Tab
          _CategoryTab(
            label: 'All',
            icon: Icons.dashboard_rounded,
            color: _accentColor,
            count: allTemplates.length,
            isSelected: _selectedCategoryId == null,
            isDark: isDark,
            onTap: () => setState(() => _selectedCategoryId = null),
          ),
          const SizedBox(width: 8),
          
          // Category Tabs
          ...usedCategories.map((category) {
            final count = categoryCounts[category.id] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _CategoryTab(
                label: category.name,
                icon: category.icon,
                color: category.color,
                count: count,
                isSelected: _selectedCategoryId == category.id,
                isDark: isDark,
                onTap: () => setState(() => _selectedCategoryId = category.id),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isDark, List<TaskTemplate> allTemplates) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // Quick Filters
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    icon: Icons.grid_view_rounded,
                    isSelected: _activeFilter == TemplateFilter.all,
                    isDark: isDark,
                    onTap: () => setState(() => _activeFilter = TemplateFilter.all),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: 'Most Used',
                    icon: Icons.trending_up_rounded,
                    isSelected: _activeFilter == TemplateFilter.mostUsed,
                    isDark: isDark,
                    onTap: () => setState(() => _activeFilter = TemplateFilter.mostUsed),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: 'Recent',
                    icon: Icons.history_rounded,
                    isSelected: _activeFilter == TemplateFilter.recent,
                    isDark: isDark,
                    onTap: () => setState(() => _activeFilter = TemplateFilter.recent),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: 'High Priority',
                    icon: Icons.priority_high_rounded,
                    isSelected: _activeFilter == TemplateFilter.highPriority,
                    isDark: isDark,
                    color: const Color(0xFFFF5252),
                    onTap: () => setState(() => _activeFilter = TemplateFilter.highPriority),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: 'Never Used',
                    icon: Icons.new_releases_outlined,
                    isSelected: _activeFilter == TemplateFilter.neverUsed,
                    isDark: isDark,
                    onTap: () => setState(() => _activeFilter = TemplateFilter.neverUsed),
                  ),
                ],
              ),
            ),
          ),
          
          // Sort Button
          const SizedBox(width: 8),
          _SortButton(
            activeSort: _activeSort,
            isDescending: _sortDescending,
            isDark: isDark,
            onSortChanged: (sort) => setState(() => _activeSort = sort),
            onDirectionChanged: () => setState(() => _sortDescending = !_sortDescending),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, bool noTemplatesAtAll) {
    final String title;
    final String subtitle;
    final IconData icon;

    if (noTemplatesAtAll) {
      title = 'No Templates Yet';
      subtitle = 'Create templates for tasks you do often.';
      icon = Icons.dashboard_customize_rounded;
    } else if (_searchQuery.isNotEmpty) {
      title = 'No Results';
      subtitle = 'No templates match "$_searchQuery"';
      icon = Icons.search_off_rounded;
    } else {
      title = 'No Templates Found';
      subtitle = 'Try adjusting your filters or category selection';
      icon = Icons.filter_alt_off_rounded;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: _accentColor.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 14,
              ),
            ),
            if (noTemplatesAtAll) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _navigateToCreateTemplate(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create First Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ] else ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _activeFilter = TemplateFilter.all;
                    _selectedCategoryId = null;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTemplatesGrid(
    BuildContext context,
    bool isDark,
    List<TaskTemplate> templates,
    List<Category> categories,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: templates.length + 1, // +1 for the "New Template" button
      itemBuilder: (context, index) {
        // Last item is the "New Template" button
        if (index == templates.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 16),
            child: Center(
              child: TextButton.icon(
                onPressed: () => _navigateToCreateTemplate(context),
                style: TextButton.styleFrom(
                  foregroundColor: _accentColor,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Template', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ),
          );
        }

        final template = templates[index];
        Category? category;
        if (template.categoryId != null) {
          try {
            category = categories.firstWhere((c) => c.id == template.categoryId);
          } catch (_) {}
        }

        return _TemplateCard(
          template: template,
          category: category,
          isDark: isDark,
          onTap: () => _showTemplateOptions(context, template, category),
          onDelete: () => _confirmDeleteTemplate(context, template),
        );
      },
    );
  }

  void _showAdvancedFilters(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E2128) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AdvancedFiltersSheet(
        isDark: isDark,
        activeSort: _activeSort,
        sortDescending: _sortDescending,
        onSortChanged: (sort) {
          setState(() => _activeSort = sort);
          Navigator.pop(context);
        },
        onDirectionChanged: (desc) {
          setState(() => _sortDescending = desc);
          Navigator.pop(context);
        },
        onReset: () {
          setState(() {
            _activeFilter = TemplateFilter.all;
            _activeSort = TemplateSort.name;
            _sortDescending = true;
            _selectedCategoryId = null;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showTemplateOptions(BuildContext context, TaskTemplate template, Category? category) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryColor = category?.color ?? _accentColor;
    final templateIcon = template.icon ?? Icons.task_alt_rounded;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E2128) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Template Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        categoryColor.withOpacity(0.2),
                        categoryColor.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(templateIcon, size: 24, color: categoryColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      if (category != null)
                        Text(
                          category.name,
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
                    color: _accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 14, color: _accentColor),
                      const SizedBox(width: 4),
                      Text(
                        '${template.usageCount}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Options
            _OptionButton(
              icon: Icons.edit_rounded,
              label: 'Edit Template',
              subtitle: 'Modify template details',
              color: _accentColor,
              isDark: isDark,
              onTap: () {
                Navigator.pop(context);
                _navigateToEditTemplate(context, template);
              },
            ),
            const SizedBox(height: 8),
            _OptionButton(
              icon: Icons.analytics_rounded,
              label: 'View Report',
              subtitle: 'See usage timeline & statistics',
              color: const Color(0xFF4CAF50),
              isDark: isDark,
              onTap: () {
                Navigator.pop(context);
                _navigateToReport(context, template, category);
              },
            ),
            const SizedBox(height: 8),
            _OptionButton(
              icon: Icons.delete_rounded,
              label: 'Delete Template',
              subtitle: 'Remove this template permanently',
              color: Colors.red,
              isDark: isDark,
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteTemplate(context, template);
              },
            ),
            
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _navigateToCreateTemplate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const EditTemplateScreen(),
      ),
    );
  }

  void _navigateToEditTemplate(BuildContext context, TaskTemplate template) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditTemplateScreen(template: template),
      ),
    );
  }

  void _navigateToReport(BuildContext context, TaskTemplate template, Category? category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TemplateReportScreen(template: template, category: category),
      ),
    );
  }

  Future<void> _confirmDeleteTemplate(BuildContext context, TaskTemplate template) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_rounded, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Delete Template', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${template.title}"?',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
            ),
            if (template.usageCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: _accentColor),
                    const SizedBox(width: 8),
                    Text(
                      'Used ${template.usageCount} time${template.usageCount == 1 ? '' : 's'}',
                      style: TextStyle(color: _accentColor, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(templateNotifierProvider.notifier).deleteTemplate(template.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template "${template.title}" deleted'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}

/// Category Tab Widget
class _CategoryTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int count;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryTab({
    required this.label,
    required this.icon,
    required this.color,
    required this.count,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.2)
                : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? color : (isDark ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? color : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.3) : (isDark ? Colors.white12 : Colors.black12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? color : (isDark ? Colors.white54 : Colors.black54),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filter Chip Widget
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    this.color,
    required this.onTap,
  });

  static const Color _accentColor = Color(0xFFCDAF56);

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? _accentColor;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? chipColor.withOpacity(0.15)
                : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey.withOpacity(0.08)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? chipColor.withOpacity(0.5) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 12,
                color: isSelected ? chipColor : (isDark ? Colors.white38 : Colors.black38),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? chipColor : (isDark ? Colors.white54 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sort Button Widget
class _SortButton extends StatelessWidget {
  final TemplateSort activeSort;
  final bool isDescending;
  final bool isDark;
  final Function(TemplateSort) onSortChanged;
  final VoidCallback onDirectionChanged;

  const _SortButton({
    required this.activeSort,
    required this.isDescending,
    required this.isDark,
    required this.onSortChanged,
    required this.onDirectionChanged,
  });

  String get _sortLabel {
    switch (activeSort) {
      case TemplateSort.name:
        return 'Name';
      case TemplateSort.usageCount:
        return 'Uses';
      case TemplateSort.lastUsed:
        return 'Recent';
      case TemplateSort.priority:
        return 'Priority';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TemplateSort>(
      onSelected: onSortChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? const Color(0xFF2D3139) : Colors.white,
      offset: const Offset(0, 40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onDirectionChanged,
              child: Icon(
                isDescending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                size: 14,
                color: const Color(0xFFCDAF56),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              _sortLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.unfold_more_rounded,
              size: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        _buildSortMenuItem(TemplateSort.name, 'Name', Icons.sort_by_alpha_rounded),
        _buildSortMenuItem(TemplateSort.usageCount, 'Usage Count', Icons.trending_up_rounded),
        _buildSortMenuItem(TemplateSort.lastUsed, 'Last Used', Icons.schedule_rounded),
        _buildSortMenuItem(TemplateSort.priority, 'Priority', Icons.flag_rounded),
      ],
    );
  }

  PopupMenuItem<TemplateSort> _buildSortMenuItem(TemplateSort sort, String label, IconData icon) {
    final isActive = activeSort == sort;
    return PopupMenuItem(
      value: sort,
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isActive ? const Color(0xFFCDAF56) : (isDark ? Colors.white54 : Colors.black54),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? const Color(0xFFCDAF56) : null,
            ),
          ),
          if (isActive) ...[
            const Spacer(),
            const Icon(Icons.check_rounded, size: 16, color: Color(0xFFCDAF56)),
          ],
        ],
      ),
    );
  }
}

/// Template Card Widget
class _TemplateCard extends StatelessWidget {
  final TaskTemplate template;
  final Category? category;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TemplateCard({
    required this.template,
    required this.category,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
  });

  static const Color _accentColor = Color(0xFFCDAF56);

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

  @override
  Widget build(BuildContext context) {
    final priorityColor = _getPriorityColor(template.priority);
    final categoryColor = category?.color ?? Colors.grey;
    final templateIcon = template.icon ?? Icons.task_alt_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262A32) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        categoryColor.withOpacity(0.2),
                        categoryColor.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(templateIcon, size: 22, color: categoryColor),
                ),
                const SizedBox(width: 12),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title Row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              template.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Priority Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: priorityColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              template.priority.toUpperCase(),
                              style: TextStyle(
                                color: priorityColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // Category
                      if (category != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(category!.icon, size: 11, color: categoryColor.withOpacity(0.8)),
                            const SizedBox(width: 4),
                            Text(
                              category!.name,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      ],
                      
                      const SizedBox(height: 8),
                      
                      // Stats Row
                      Row(
                        children: [
                          // Usage Count
                          _MiniStat(
                            icon: Icons.play_arrow_rounded,
                            label: '${template.usageCount}',
                            color: _accentColor,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 12),
                          
                          // Last Used
                          _MiniStat(
                            icon: Icons.schedule_rounded,
                            label: template.lastUsedAgo,
                            color: isDark ? Colors.white38 : Colors.black38,
                            isDark: isDark,
                          ),
                          
                          // Subtasks count
                          if (template.defaultSubtasks != null && template.defaultSubtasks!.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            _MiniStat(
                              icon: Icons.checklist_rounded,
                              label: '${template.defaultSubtasks!.length}',
                              color: isDark ? Colors.white38 : Colors.black38,
                              isDark: isDark,
                            ),
                          ],
                          
                          const Spacer(),
                          
                          // Delete Button
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red[300]),
                              onPressed: onDelete,
                            ),
                          ),
                        ],
                      ),
                    ],
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

/// Mini Stat Widget
class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Advanced Filters Bottom Sheet
class _AdvancedFiltersSheet extends StatelessWidget {
  final bool isDark;
  final TemplateSort activeSort;
  final bool sortDescending;
  final Function(TemplateSort) onSortChanged;
  final Function(bool) onDirectionChanged;
  final VoidCallback onReset;

  const _AdvancedFiltersSheet({
    required this.isDark,
    required this.activeSort,
    required this.sortDescending,
    required this.onSortChanged,
    required this.onDirectionChanged,
    required this.onReset,
  });

  static const Color _accentColor = Color(0xFFCDAF56);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune_rounded, size: 18, color: _accentColor),
              ),
              const SizedBox(width: 12),
              Text(
                'Advanced Filters',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onReset,
                child: const Text('Reset', style: TextStyle(color: _accentColor, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Sort Section
          Text(
            'SORT BY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black38,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SortOption(
                label: 'Name',
                icon: Icons.sort_by_alpha_rounded,
                isSelected: activeSort == TemplateSort.name,
                isDark: isDark,
                onTap: () => onSortChanged(TemplateSort.name),
              ),
              _SortOption(
                label: 'Usage Count',
                icon: Icons.trending_up_rounded,
                isSelected: activeSort == TemplateSort.usageCount,
                isDark: isDark,
                onTap: () => onSortChanged(TemplateSort.usageCount),
              ),
              _SortOption(
                label: 'Last Used',
                icon: Icons.schedule_rounded,
                isSelected: activeSort == TemplateSort.lastUsed,
                isDark: isDark,
                onTap: () => onSortChanged(TemplateSort.lastUsed),
              ),
              _SortOption(
                label: 'Priority',
                icon: Icons.flag_rounded,
                isSelected: activeSort == TemplateSort.priority,
                isDark: isDark,
                onTap: () => onSortChanged(TemplateSort.priority),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Sort Direction
          Text(
            'SORT DIRECTION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black38,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          
          Row(
            children: [
              Expanded(
                child: _SortOption(
                  label: 'Descending',
                  icon: Icons.arrow_downward_rounded,
                  isSelected: sortDescending,
                  isDark: isDark,
                  onTap: () => onDirectionChanged(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SortOption(
                  label: 'Ascending',
                  icon: Icons.arrow_upward_rounded,
                  isSelected: !sortDescending,
                  isDark: isDark,
                  onTap: () => onDirectionChanged(false),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Sort Option Widget
class _SortOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _SortOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  static const Color _accentColor = Color(0xFFCDAF56);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? _accentColor.withOpacity(0.15)
                : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? _accentColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? _accentColor : (isDark ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? _accentColor : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Option Button Widget for bottom sheet
class _OptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _OptionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
