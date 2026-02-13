import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/habit_unit.dart';
import '../../../data/models/unit_category.dart';
import '../../providers/habit_unit_providers.dart';
import '../../providers/unit_category_providers.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../../core/widgets/sheet_dismiss_on_overscroll.dart';

/// Screen for managing habit measurement units
class HabitUnitsScreen extends ConsumerWidget {
  const HabitUnitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unitsAsync = ref.watch(habitUnitNotifierProvider);
    final categoriesAsync = ref.watch(unitCategoryNotifierProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: categoriesAsync.when(
        data: (categories) => unitsAsync.when(
          data: (units) => _buildContent(context, isDark, categories, units, ref),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error loading units: $error')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error loading categories: $error')),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    List<UnitCategory> categories,
    List<HabitUnit> units,
    WidgetRef ref,
  ) {
    // Group units by category
    final groupedUnits = <UnitCategory, List<HabitUnit>>{};
    for (final category in categories) {
      final categoryUnits = units.where((u) => u.categoryId == category.id).toList();
      if (categoryUnits.isNotEmpty) {
        groupedUnits[category] = categoryUnits;
      }
    }

    final accentColor = Theme.of(context).colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      children: [
        // Header
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Measurement Units',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create custom categories and units for your habits.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Units by category
        ...groupedUnits.entries.map((entry) => _buildCategorySection(
              context,
              isDark,
              entry.key,
              entry.value,
              ref,
            )),

        const SizedBox(height: 40),

        // Action Buttons
        _buildActionButtons(context, isDark, ref, accentColor),
        
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isDark, WidgetRef ref, Color accentColor) {
    return Column(
      children: [
        Text(
          'NEED MORE?',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: isDark ? Colors.grey[700] : Colors.grey[400],
              ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSmallActionButton(
              context: context,
              isDark: isDark,
              label: 'Category',
              icon: Icons.category_outlined,
              color: const Color(0xFF2196F3),
              onPressed: () => _showAddCategorySheet(context, isDark, ref),
            ),
            const SizedBox(width: 12),
            _buildSmallActionButton(
              context: context,
              isDark: isDark,
              label: 'New Unit',
              icon: Icons.add_circle_outline,
              color: const Color(0xFFCDAF56),
              onPressed: () => _showAddUnitSheet(context, isDark, ref),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallActionButton({
    required BuildContext context,
    required bool isDark,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    bool isDark,
    UnitCategory category,
    List<HabitUnit> units,
    WidgetRef ref,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  category.icon,
                  color: category.color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                category.name.toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: category.color,
                    ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_horiz, size: 20, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditCategorySheet(context, isDark, category, ref);
                  } else if (value == 'delete') {
                    _showDeleteCategoryDialog(context, category, ref);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18, color: category.color),
                        const SizedBox(width: 12),
                        const Text('Edit Category'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        const SizedBox(width: 12),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Units Grid
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: units.map((unit) => _buildUnitChip(context, isDark, unit, category, ref)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitChip(BuildContext context, bool isDark, HabitUnit unit, UnitCategory category, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showUnitDetails(context, isDark, unit, category, ref),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (unit.iconCodePoint != null)
                Icon(
                  IconData(unit.iconCodePoint!, fontFamily: unit.iconFontFamily),
                  size: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              if (unit.iconCodePoint != null) const SizedBox(width: 8),
              Text(
                unit.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
              ),
              const SizedBox(width: 6),
              Text(
                unit.symbol,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: category.color.withOpacity(0.8),
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnitDetails(BuildContext context, bool isDark, HabitUnit unit, UnitCategory category, WidgetRef ref) {
    final errorColor = Theme.of(context).colorScheme.error;
    final warningColor = const Color(0xFFCDAF56);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SheetDismissOnOverscroll(
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
          ),
          child: Container(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D21) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Pull Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  if (unit.iconCodePoint != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: category.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        IconData(unit.iconCodePoint!, fontFamily: unit.iconFontFamily),
                        color: category.color,
                        size: 32,
                      ),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit.name,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                        ),
                        Text(
                          '${category.name} Category',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: category.color,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Info Grid
              Row(
                children: [
                  _buildDetailTile(context, isDark, 'Symbol', unit.symbol, Icons.label_outline),
                  const SizedBox(width: 12),
                  _buildDetailTile(context, isDark, 'Plural', unit.pluralName, Icons.format_list_bulleted),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 18, color: warningColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Example: 5 ${unit.pluralName} = 5${unit.symbol}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.grey[400] : Colors.grey[700],
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditUnitSheet(context, isDark, unit, ref);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit Unit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                        foregroundColor: isDark ? Colors.white : Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final confirm = await _showDeleteConfirmation(context, 'Unit', unit.name);
                        if (confirm == true && context.mounted) {
                          await ref.read(habitUnitNotifierProvider.notifier).deleteUnit(unit.id);
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                      icon: Icon(Icons.delete_outline, size: 18, color: errorColor),
                      label: Text('Delete', style: TextStyle(color: errorColor)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: errorColor.withOpacity(0.1),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildDetailTile(BuildContext context, bool isDark, String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: isDark ? Colors.grey[600] : Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: isDark ? Colors.grey[600] : Colors.grey[500],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context, String type, String name) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Delete $type?'),
        content: Text('Are you sure you want to delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddUnitSheet(BuildContext context, bool isDark, WidgetRef ref) {
    _showUnitFormSheet(context, isDark, ref, null);
  }

  void _showEditUnitSheet(BuildContext context, bool isDark, HabitUnit unit, WidgetRef ref) {
    _showUnitFormSheet(context, isDark, ref, unit);
  }

  void _showUnitFormSheet(BuildContext context, bool isDark, WidgetRef ref, HabitUnit? existingUnit) {
    final categoriesAsync = ref.read(unitCategoryNotifierProvider);
    
    categoriesAsync.whenData((categories) {
      final isEdit = existingUnit != null;
      final nameController = TextEditingController(text: existingUnit?.name ?? '');
      final symbolController = TextEditingController(text: existingUnit?.symbol ?? '');
      final pluralController = TextEditingController(text: existingUnit?.pluralName ?? '');
      String selectedCategoryId = existingUnit?.categoryId ?? categories.first.id;

      final accentColor = Theme.of(context).colorScheme.primary;
      final successColor = isDark ? Colors.green[400]! : Colors.green[700]!;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => SheetDismissOnOverscroll(
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
              ),
              child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 10,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D21) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pull Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    Text(
                      isEdit ? 'Edit Unit' : 'New Custom Unit',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                    ),
                    const SizedBox(height: 24),

                    _buildSectionHeader(context, isDark, 'UNIT DETAILS'),
                    const SizedBox(height: 16),

                    _buildModernInputField(
                      context: context,
                      isDark: isDark,
                      label: 'Unit Name',
                      controller: nameController,
                      icon: Icons.label_outline,
                      hint: 'e.g., Pushup',
                      onChanged: (value) {
                        if (pluralController.text.isEmpty || pluralController.text == '${nameController.text}s') {
                          pluralController.text = '${value}s';
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildModernInputField(
                            context: context,
                            isDark: isDark,
                            label: 'Symbol',
                            controller: symbolController,
                            icon: Icons.short_text,
                            hint: 'reps',
                            maxLength: 10,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: _buildModernInputField(
                            context: context,
                            isDark: isDark,
                            label: 'Plural Name',
                            controller: pluralController,
                            icon: Icons.format_list_bulleted,
                            hint: 'Pushups',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildSectionHeader(context, isDark, 'CATEGORY'),
                    const SizedBox(height: 16),
                    
                    Container(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categories.map((category) {
                          final isSelected = selectedCategoryId == category.id;
                          return GestureDetector(
                            onTap: () {
                              setState(() => selectedCategoryId = category.id);
                              HapticFeedback.selectionClick();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? category.color.withOpacity(0.15) 
                                    : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? category.color : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    category.icon, 
                                    size: 14, 
                                    color: isSelected ? category.color : (isDark ? Colors.grey[500] : Colors.grey[600]),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    category.name,
                                    style: TextStyle(
                                      color: isSelected ? category.color : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    
                    const SizedBox(height: 40),

                    // Save Button
                    Container(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          final name = nameController.text.trim();
                          final symbol = symbolController.text.trim();
                          final plural = pluralController.text.trim();

                          if (name.isEmpty || symbol.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Name and Symbol are required'), backgroundColor: Colors.red),
                            );
                            return;
                          }

                          final selectedCategory = categories.firstWhere((c) => c.id == selectedCategoryId);
                          final unit = HabitUnit(
                            id: existingUnit?.id,
                            name: name,
                            symbol: symbol,
                            pluralName: plural.isEmpty ? '${name}s' : plural,
                            categoryId: selectedCategoryId,
                            isDefault: false,
                            iconCodePoint: selectedCategory.iconCodePoint,
                            iconFontFamily: selectedCategory.iconFontFamily,
                            createdAt: existingUnit?.createdAt,
                          );

                          if (isEdit) {
                            ref.read(habitUnitNotifierProvider.notifier).updateUnit(unit);
                          } else {
                            ref.read(habitUnitNotifierProvider.notifier).addUnit(unit);
                          }

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isEdit ? 'Unit updated!' : 'Unit created!'),
                              backgroundColor: successColor,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          isEdit ? 'Save Changes' : 'Create Unit',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      );
    });
  }

  void _showAddCategorySheet(BuildContext context, bool isDark, WidgetRef ref) {
    _showCategoryFormSheet(context, isDark, ref, null);
  }

  void _showEditCategorySheet(BuildContext context, bool isDark, UnitCategory category, WidgetRef ref) {
    _showCategoryFormSheet(context, isDark, ref, category);
  }

  void _showCategoryFormSheet(BuildContext context, bool isDark, WidgetRef ref, UnitCategory? existingCategory) {
    final isEdit = existingCategory != null;
    final nameController = TextEditingController(text: existingCategory?.name ?? '');
    IconData selectedIcon = existingCategory?.icon ?? Icons.category_outlined;
    Color selectedColor = existingCategory?.color ?? const Color(0xFFCDAF56);

    final accentColor = Theme.of(context).colorScheme.primary;
    final successColor = isDark ? Colors.green[400]! : Colors.green[700]!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => SheetDismissOnOverscroll(
          child: Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
            ),
            child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 10,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D21) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pull Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  Text(
                    isEdit ? 'Edit Category' : 'New Category',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionHeader(context, isDark, 'CATEGORY DETAILS'),
                  const SizedBox(height: 16),

                  _buildModernInputField(
                    context: context,
                    isDark: isDark,
                    label: 'Category Name',
                    controller: nameController,
                    icon: Icons.category_outlined,
                    hint: 'e.g., Exercise, Mindset',
                  ),
                  const SizedBox(height: 24),

                  _buildSectionHeader(context, isDark, 'APPEARANCE'),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      // Icon Picker
                      Expanded(
                        child: _buildPickerButton(
                          context, 
                          isDark, 
                          'Icon', 
                          Icon(selectedIcon, color: selectedColor, size: 28),
                          () async {
                            final icon = await showDialog<IconData>(
                              context: context,
                              builder: (context) => IconPickerWidget(
                                selectedIcon: selectedIcon,
                                isDark: isDark,
                              ),
                            );
                            if (icon != null) {
                              setState(() => selectedIcon = icon);
                            }
                          }
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Color Picker
                      Expanded(
                        child: _buildPickerButton(
                          context, 
                          isDark, 
                          'Color', 
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: selectedColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                            ),
                          ),
                          () async {
                            final color = await showDialog<Color>(
                              context: context,
                              builder: (context) => ColorPickerWidget(
                                selectedColor: selectedColor,
                                isDark: isDark,
                              ),
                            );
                            if (color != null) {
                              setState(() => selectedColor = color);
                            }
                          }
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 40),

                  // Save Button
                  Container(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        final name = nameController.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Category name is required'), backgroundColor: Colors.red),
                          );
                          return;
                        }

                        final sortOrder = isEdit 
                            ? existingCategory.sortOrder 
                            : ref.read(unitCategoryNotifierProvider.notifier).getNextSortOrder();

                        final category = UnitCategory(
                          id: existingCategory?.id,
                          name: name,
                          iconCodePoint: selectedIcon.codePoint,
                          iconFontFamily: selectedIcon.fontFamily,
                          iconFontPackage: selectedIcon.fontPackage,
                          colorValue: selectedColor.value,
                          isDefault: false,
                          sortOrder: sortOrder,
                          createdAt: existingCategory?.createdAt,
                        );

                        if (isEdit) {
                          ref.read(unitCategoryNotifierProvider.notifier).updateCategory(category);
                        } else {
                          ref.read(unitCategoryNotifierProvider.notifier).addCategory(category);
                        }

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isEdit ? 'Category updated!' : 'Category created!'),
                            backgroundColor: successColor,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        isEdit ? 'Save Changes' : 'Create Category',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildPickerButton(BuildContext context, bool isDark, String label, Widget preview, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.grey[600] : Colors.grey[500],
                  ),
            ),
            const SizedBox(height: 12),
            preview,
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, bool isDark, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: isDark ? Colors.grey[700] : Colors.grey[400],
          ),
    );
  }

  Widget _buildModernInputField({
    required BuildContext context,
    required bool isDark,
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    String? prefixText,
    int? maxLength,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
          ),
        ),
        TextField(
          controller: controller,
          onChanged: onChanged,
          maxLength: maxLength,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            counterText: '',
            prefixIcon: Icon(icon, color: isDark ? Colors.grey[600] : Colors.grey[400], size: 20),
            prefixText: prefixText,
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? Colors.grey[700] : Colors.grey[400]),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  void _showDeleteCategoryDialog(BuildContext context, UnitCategory category, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Category?'),
        content: Text(
          'Are you sure you want to delete "${category.name}"?\n\nAll units in this category will remain but will need to be reassigned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () async {
              final success = await ref.read(unitCategoryNotifierProvider.notifier).deleteCategory(category.id);
              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Category deleted!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cannot delete default category'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
