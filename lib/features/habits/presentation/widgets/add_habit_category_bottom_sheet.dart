import 'package:flutter/material.dart';
import '../../data/models/habit_category.dart';
import '../../../../core/services/custom_color_service.dart';
import '../../../../core/widgets/icon_picker_widget.dart';
import '../../../../core/widgets/color_picker_widget.dart';

/// Bottom sheet for creating/editing habit categories
class AddHabitCategoryBottomSheet extends StatefulWidget {
  final HabitCategory? category;

  const AddHabitCategoryBottomSheet({super.key, this.category});

  @override
  State<AddHabitCategoryBottomSheet> createState() => _AddHabitCategoryBottomSheetState();
}

class _AddHabitCategoryBottomSheetState extends State<AddHabitCategoryBottomSheet> {
  final _nameController = TextEditingController();
  IconData _selectedIcon = Icons.category_rounded;
  Color _selectedColor = Colors.blue;
  List<Color> _savedColors = [];

  final List<Color> _availableColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.purple,
    Colors.pink,
    Colors.teal,
    Colors.amber,
    Colors.indigo,
    Colors.cyan,
    Colors.deepOrange,
    Colors.brown,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _selectedIcon = widget.category!.icon;
      _selectedColor = widget.category!.color;
    }
    _loadSavedColors();
  }

  Future<void> _loadSavedColors() async {
    final saved = await CustomColorService.getSavedColors();
    setState(() {
      _savedColors = saved;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.category != null ? 'Edit Habit Category' : 'Create Habit Category',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _nameController,
                autofocus: widget.category == null,
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  labelStyle: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                  hintText: 'e.g., Spiritual, Fitness, Hygiene',
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black26),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  border: InputBorder.none,
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                ),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: _selectedColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedColor,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _selectedColor.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _selectedIcon,
                      color: _selectedColor,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Preview',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white60 : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionLabel(context, isDark, 'CHOOSE ICON'),
            const SizedBox(height: 16),
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildIconButton(context, isDark),
                  const SizedBox(width: 12),
                  ...[
                    Icons.self_improvement_rounded,
                    Icons.menu_book_rounded,
                    Icons.favorite_rounded,
                    Icons.shower_rounded,
                    Icons.fitness_center_rounded,
                    Icons.home_rounded,
                    Icons.psychology_rounded,
                    Icons.phone_android_rounded,
                  ].map((icon) => _buildQuickIcon(icon)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionLabel(context, isDark, 'CHOOSE COLOR'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                ..._availableColors.map((color) => _buildColorOption(color)),
                _buildCustomColorButton(context, isDark),
              ],
            ),
            if (_savedColors.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSectionLabel(context, isDark, 'SAVED COLORS'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: _savedColors.map((color) => _buildColorOption(color, isSaved: true)).toList(),
              ),
            ],
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  if (_nameController.text.trim().isNotEmpty) {
                    final category = widget.category != null
                        ? widget.category!.copyWith(
                            name: _nameController.text.trim(),
                            icon: _selectedIcon,
                            color: _selectedColor,
                            updatedAt: DateTime.now(),
                          )
                        : HabitCategory.fromIcon(
                            name: _nameController.text.trim(),
                            icon: _selectedIcon,
                            color: _selectedColor,
                          );
                    Navigator.pop(context, category);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCDAF56),
                  foregroundColor: const Color(0xFF1E1E1E),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.category != null ? Icons.check_circle_rounded : Icons.add_circle_rounded),
                    const SizedBox(width: 12),
                    Text(
                      widget.category != null ? 'Save Changes' : 'Create Category',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E1E1E),
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

  Widget _buildSectionLabel(BuildContext context, bool isDark, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: isDark ? Colors.white38 : Colors.black38,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
    );
  }

  Widget _buildIconButton(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => _openIconPicker(),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 1,
          ),
        ),
        child: Icon(Icons.more_horiz_rounded, color: isDark ? Colors.white : Colors.black54),
      ),
    );
  }

  Widget _buildQuickIcon(IconData icon) {
    final isSelected = _selectedIcon == icon;
    return GestureDetector(
      onTap: () => setState(() => _selectedIcon = icon),
      child: Container(
        width: 60,
        height: 60,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? _selectedColor : (Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? _selectedColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
          size: 26,
        ),
      ),
    );
  }

  Widget _buildColorOption(Color color, {bool isSaved = false}) {
    final isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87) : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 24) : null,
      ),
    );
  }

  Widget _buildCustomColorButton(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => _openColorPicker(),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 1,
          ),
        ),
        child: Icon(Icons.colorize_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black54),
      ),
    );
  }

  Future<void> _openIconPicker() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final icon = await showDialog<IconData>(
      context: context,
      builder: (context) => IconPickerWidget(
        selectedIcon: _selectedIcon,
        isDark: isDark,
      ),
    );
    if (icon != null) {
      setState(() => _selectedIcon = icon);
    }
  }

  Future<void> _openColorPicker() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerWidget(
        selectedColor: _selectedColor,
        isDark: isDark,
      ),
    );
    if (color != null) {
      setState(() => _selectedColor = color);
      if (!_availableColors.contains(color) && !_savedColors.contains(color)) {
        CustomColorService.saveColor(color);
        _loadSavedColors();
      }
    }
  }
}
