import 'package:flutter/material.dart';
import '../../data/models/habit_type.dart';

/// Bottom sheet for creating/editing habit types with point values
class AddHabitTypeBottomSheet extends StatefulWidget {
  final HabitType? habitType; // If provided, we're editing

  const AddHabitTypeBottomSheet({super.key, this.habitType});

  @override
  State<AddHabitTypeBottomSheet> createState() => _AddHabitTypeBottomSheetState();
}

class _AddHabitTypeBottomSheetState extends State<AddHabitTypeBottomSheet> {
  final _nameController = TextEditingController();
  final _basePointsController = TextEditingController();
  final _rewardOnDoneController = TextEditingController();
  final _penaltyNotDoneController = TextEditingController();
  final _penaltyPostponeController = TextEditingController();

  bool _useDefaultValues = true;

  @override
  void initState() {
    super.initState();
    if (widget.habitType != null) {
      // Editing mode - populate fields
      _nameController.text = widget.habitType!.name;
      _basePointsController.text = widget.habitType!.basePoints.toString();
      _rewardOnDoneController.text = widget.habitType!.rewardOnDone.toString();
      _penaltyNotDoneController.text = widget.habitType!.penaltyNotDone.toString();
      _penaltyPostponeController.text = widget.habitType!.penaltyPostpone.toString();
      _useDefaultValues = false;
    } else {
      // Creating mode - set defaults
      _basePointsController.text = '10';
      _rewardOnDoneController.text = '10';
      _penaltyNotDoneController.text = '-10';
      _penaltyPostponeController.text = '-5';
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
              widget.habitType != null ? 'Edit Habit Type' : 'Create Habit Type',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
            ),
            const SizedBox(height: 24),

            // Habit Type Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Habit Type Name',
                hintText: 'e.g., Health Habit, Work Habit',
                filled: true,
                fillColor: isDark ? Colors.black.withOpacity(0.4) : Colors.grey[200],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFCDAF56), width: 2),
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
                    final habitType = widget.habitType != null
                        ? widget.habitType!.copyWith(
                            name: _nameController.text,
                            basePoints: int.tryParse(_basePointsController.text) ?? 10,
                            rewardOnDone: int.tryParse(_rewardOnDoneController.text) ?? 10,
                            penaltyNotDone: int.tryParse(_penaltyNotDoneController.text) ?? -10,
                            penaltyPostpone: int.tryParse(_penaltyPostponeController.text) ?? -5,
                            updatedAt: DateTime.now(),
                          )
                        : HabitType(
                            name: _nameController.text,
                            basePoints: int.tryParse(_basePointsController.text) ?? 10,
                            rewardOnDone: int.tryParse(_rewardOnDoneController.text) ?? 10,
                            penaltyNotDone: int.tryParse(_penaltyNotDoneController.text) ?? -10,
                            penaltyPostpone: int.tryParse(_penaltyPostponeController.text) ?? -5,
                          );
                    Navigator.pop(context, habitType);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCDAF56),
                  foregroundColor: const Color(0xFF1E1E1E),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  widget.habitType != null ? 'Save Changes' : 'Create Habit Type',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E1E1E),
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
