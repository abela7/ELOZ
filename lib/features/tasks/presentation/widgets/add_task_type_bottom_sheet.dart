import 'package:flutter/material.dart';
import '../../../../data/models/task_type.dart';
import '../../../../core/widgets/icon_picker_widget.dart';
import '../../../../core/widgets/color_picker_widget.dart';

/// Bottom sheet for creating/editing task types with point values
class AddTaskTypeBottomSheet extends StatefulWidget {
  final TaskType? taskType; // If provided, we're editing

  const AddTaskTypeBottomSheet({super.key, this.taskType});

  @override
  State<AddTaskTypeBottomSheet> createState() => _AddTaskTypeBottomSheetState();
}

class _AddTaskTypeBottomSheetState extends State<AddTaskTypeBottomSheet> {
  final _nameController = TextEditingController();
  final _basePointsController = TextEditingController();
  final _rewardOnDoneController = TextEditingController();
  final _penaltyNotDoneController = TextEditingController();
  final _penaltyPostponeController = TextEditingController();

  IconData? _selectedIcon;
  Color _selectedColor = const Color(0xFFCDAF56);
  bool _useDefaultValues = true;

  @override
  void initState() {
    super.initState();
    if (widget.taskType != null) {
      // Editing mode - populate fields
      _nameController.text = widget.taskType!.name;
      _basePointsController.text = widget.taskType!.basePoints.toString();
      _rewardOnDoneController.text = widget.taskType!.rewardOnDone.toString();
      _penaltyNotDoneController.text = widget.taskType!.penaltyNotDone.toString();
      _penaltyPostponeController.text = widget.taskType!.penaltyPostpone.toString();
      _useDefaultValues = false;
      if (widget.taskType!.iconCode != null) {
        _selectedIcon = IconData(widget.taskType!.iconCode!, fontFamily: 'MaterialIcons');
      }
      if (widget.taskType!.colorValue != null) {
        _selectedColor = Color(widget.taskType!.colorValue!);
      }
    } else {
      // Creating mode - set defaults
      _basePointsController.text = '10';
      _rewardOnDoneController.text = '10';
      _penaltyNotDoneController.text = '-10';
      _penaltyPostponeController.text = '-5';
      _selectedIcon = Icons.star_rounded; // Default icon
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _basePointsController.dispose();
    _rewardOnDoneController.dispose();
    _penaltyNotDoneController.dispose();
    _penaltyPostponeController.dispose();
    super.dispose();
  }

  void _updateDefaultValues() {
    if (_useDefaultValues && _basePointsController.text.isNotEmpty) {
      final basePoints = int.tryParse(_basePointsController.text) ?? 10;
      setState(() {
        _rewardOnDoneController.text = basePoints.toString();
        _penaltyNotDoneController.text = (-basePoints).toString();
        _penaltyPostponeController.text = (-(basePoints ~/ 2)).toString();
      });
    }
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
              widget.taskType != null ? 'Edit Task Level' : 'Create Task Level',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
            ),
            const SizedBox(height: 24),

            // Icon and Color Selection Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon Selection
                GestureDetector(
                  onTap: () async {
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
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.4) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedColor,
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Icon(
                            _selectedIcon ?? Icons.add_rounded,
                            size: 40,
                            color: _selectedColor,
                          ),
                        ),
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _selectedColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 12,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // Color Selection
                GestureDetector(
                  onTap: () async {
                    final color = await showDialog<Color>(
                      context: context,
                      builder: (context) => ColorPickerWidget(
                        selectedColor: _selectedColor,
                        isDark: isDark,
                      ),
                    );
                    if (color != null) {
                      setState(() => _selectedColor = color);
                    }
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _selectedColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.black12,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _selectedColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.palette_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Task Level Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Task Level Name',
                hintText: 'e.g., Work, Personal, High Focus',
                filled: true,
                fillColor: isDark ? Colors.black.withOpacity(0.4) : Colors.grey[200],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: _selectedColor, width: 2),
                ),
              ),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isDark ? Colors.white : Colors.black,
                  ),
            ),
            const SizedBox(height: 20),

            // Base Points
            TextField(
              controller: _basePointsController,
              decoration: InputDecoration(
                labelText: 'Base Points',
                hintText: 'e.g., 10',
                filled: true,
                fillColor: isDark ? Colors.black.withOpacity(0.4) : Colors.grey[200],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFCDAF56), width: 2),
                ),
              ),
              keyboardType: TextInputType.number,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isDark ? Colors.white : Colors.black,
                  ),
              onChanged: (_) {
                if (_useDefaultValues) {
                  _updateDefaultValues();
                }
              },
            ),
            const SizedBox(height: 20),

            // Use Default Values Toggle
            SwitchListTile(
              title: Text(
                'Use default point calculations',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.white : Colors.black,
                    ),
              ),
              subtitle: Text(
                'Reward: +base | Penalty: -base | Postpone: -base/2',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
              ),
              value: _useDefaultValues,
              onChanged: (value) {
                setState(() {
                  _useDefaultValues = value;
                  if (value) {
                    _updateDefaultValues();
                  }
                });
              },
              activeColor: const Color(0xFFCDAF56),
            ),
            const SizedBox(height: 16),

            // Custom Point Values (shown when toggle is off)
            if (!_useDefaultValues) ...[
              Text(
                'Custom Point Values',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
              ),
              const SizedBox(height: 16),

              // Reward on Done
              TextField(
                controller: _rewardOnDoneController,
                decoration: InputDecoration(
                  labelText: 'Reward on Done',
                  hintText: 'e.g., 10',
                  prefixText: '+',
                  filled: true,
                  fillColor: isDark ? Colors.black.withOpacity(0.4) : Colors.grey[200],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                  ),
                ),
                keyboardType: TextInputType.number,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF4CAF50),
                    ),
              ),
              const SizedBox(height: 16),

              // Penalty on Not Done
              TextField(
                controller: _penaltyNotDoneController,
                decoration: InputDecoration(
                  labelText: 'Penalty on Not Done',
                  hintText: 'e.g., -10',
                  filled: true,
                  fillColor: isDark ? Colors.black.withOpacity(0.4) : Colors.grey[200],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                ),
                keyboardType: TextInputType.number,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.red,
                    ),
              ),
              const SizedBox(height: 16),

              // Penalty on Postpone
              TextField(
                controller: _penaltyPostponeController,
                decoration: InputDecoration(
                  labelText: 'Penalty on Postpone',
                  hintText: 'e.g., -5',
                  filled: true,
                  fillColor: isDark ? Colors.black.withOpacity(0.4) : Colors.grey[200],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFCDAF56), width: 2),
                  ),
                ),
                keyboardType: TextInputType.number,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFFCDAF56),
                    ),
              ),
              const SizedBox(height: 20),
            ],

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_nameController.text.isNotEmpty &&
                      _basePointsController.text.isNotEmpty) {
                    final taskType = widget.taskType != null
                        ? widget.taskType!.copyWith(
                            name: _nameController.text,
                            basePoints: int.tryParse(_basePointsController.text) ?? 10,
                            rewardOnDone: int.tryParse(_rewardOnDoneController.text) ?? 10,
                            penaltyNotDone: int.tryParse(_penaltyNotDoneController.text) ?? -10,
                            penaltyPostpone: int.tryParse(_penaltyPostponeController.text) ?? -5,
                            updatedAt: DateTime.now(),
                            iconCode: _selectedIcon?.codePoint,
                            colorValue: _selectedColor.value,
                          )
                        : TaskType(
                            name: _nameController.text,
                            basePoints: int.tryParse(_basePointsController.text) ?? 10,
                            rewardOnDone: int.tryParse(_rewardOnDoneController.text) ?? 10,
                            penaltyNotDone: int.tryParse(_penaltyNotDoneController.text) ?? -10,
                            penaltyPostpone: int.tryParse(_penaltyPostponeController.text) ?? -5,
                            iconCode: _selectedIcon?.codePoint,
                            colorValue: _selectedColor.value,
                          );
                    Navigator.pop(context, taskType);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  widget.taskType != null ? 'Save Changes' : 'Create Task Level',
                  style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
