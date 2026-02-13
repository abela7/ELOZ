import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/add_habit_type_bottom_sheet.dart';
import '../../providers/habit_type_providers.dart';
import '../../../data/models/habit_type.dart';

/// Points System Screen - Manage habit types and their point values
class HabitPointsSystemScreen extends ConsumerWidget {
  const HabitPointsSystemScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final habitTypesAsync = ref.watch(habitTypeNotifierProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Expanded(
            child: habitTypesAsync.when(
              data: (habitTypes) => _buildContent(context, isDark, habitTypes, ref),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error loading habit types: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, List<HabitType> habitTypes, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Header
              Text(
                'Points System',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Define how habits are rewarded and penalized.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 24),

              // Habit Types List
              if (habitTypes.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.emoji_events_outlined,
                          size: 64,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No habit types created yet',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...habitTypes.map((habitType) {
                  return Card(
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.15),
                    color: isDark ? const Color(0xFF2D3139) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title and Action Icons Row
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  habitType.name,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded),
                                color: const Color(0xFFCDAF56),
                                iconSize: 20,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _editHabitType(context, isDark, habitType, ref),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_rounded),
                                color: Colors.red,
                                iconSize: 20,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _deleteHabitType(context, habitType, ref),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Base Points
                          Text(
                            'Base Point: ${habitType.basePoints} points',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                          ),
                          const SizedBox(height: 12),
                          // Point Values - Wrap to prevent overflow
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Done: +${habitType.rewardOnDone}',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: const Color(0xFF4CAF50),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Not Done: ${habitType.penaltyNotDone}',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCDAF56).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Postpone: ${habitType.penaltyPostpone}',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: const Color(0xFFCDAF56),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
            ],
          ),
        ),

        // Add Button
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddHabitTypeBottomSheet(context, isDark, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Habit Type'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCDAF56),
                foregroundColor: const Color(0xFF1E1E1E),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddHabitTypeBottomSheet(BuildContext context, bool isDark, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddHabitTypeBottomSheet(),
    ).then((result) {
      if (result != null && result is HabitType) {
        ref.read(habitTypeNotifierProvider.notifier).addHabitType(result);
      }
    });
  }

  void _editHabitType(BuildContext context, bool isDark, HabitType habitType, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddHabitTypeBottomSheet(habitType: habitType),
    ).then((result) {
      if (result != null && result is HabitType) {
        ref.read(habitTypeNotifierProvider.notifier).updateHabitType(result);
      }
    });
  }

  void _deleteHabitType(BuildContext context, HabitType habitType, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Habit Type'),
        content: Text('Are you sure you want to delete "${habitType.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(habitTypeNotifierProvider.notifier).deleteHabitType(habitType.id);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
