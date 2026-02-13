import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/dark_gradient.dart';
import '../../widgets/add_task_type_bottom_sheet.dart';
import '../../providers/task_type_providers.dart';
import '../../../../../data/models/task_type.dart';

/// Points System Screen - Manage task types and their point values
class PointsSystemScreen extends ConsumerWidget {
  const PointsSystemScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final taskTypesAsync = ref.watch(taskTypeNotifierProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Expanded(
            child: taskTypesAsync.when(
              data: (taskTypes) => _buildContent(context, isDark, taskTypes, ref),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error loading task levels: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, List<TaskType> taskTypes, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Header
              Text(
                'Task Levels',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Define how different task levels are rewarded and penalized.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 24),

              // Task Types List
              if (taskTypes.isEmpty)
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
                          'No task levels created yet',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...taskTypes.map((taskType) {
                  final color = taskType.colorValue != null ? Color(taskType.colorValue!) : const Color(0xFFCDAF56);
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
                              if (taskType.iconCode != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    IconData(taskType.iconCode!, fontFamily: 'MaterialIcons'),
                                    color: color,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ] else ...[
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Text(
                                  taskType.name,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded),
                                color: color,
                                iconSize: 20,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _editTaskType(context, isDark, taskType, ref),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_rounded),
                                color: Colors.red,
                                iconSize: 20,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _deleteTaskType(context, taskType, ref),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Base Points
                          Text(
                            'Base Point: ${taskType.basePoints} points',
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
                                  'Done: +${taskType.rewardOnDone}',
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
                                  'Not Done: ${taskType.penaltyNotDone}',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Postpone: ${taskType.penaltyPostpone}',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: color,
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
              onPressed: () => _showAddTaskTypeBottomSheet(context, isDark, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Task Level'),
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

  void _showAddTaskTypeBottomSheet(BuildContext context, bool isDark, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddTaskTypeBottomSheet(),
    ).then((result) {
      if (result != null && result is TaskType) {
        ref.read(taskTypeNotifierProvider.notifier).addTaskType(result);
      }
    });
  }

  void _editTaskType(BuildContext context, bool isDark, TaskType taskType, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTaskTypeBottomSheet(taskType: taskType),
    ).then((result) {
      if (result != null && result is TaskType) {
        ref.read(taskTypeNotifierProvider.notifier).updateTaskType(result);
      }
    });
  }

  void _deleteTaskType(BuildContext context, TaskType taskType, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task Type'),
        content: Text('Are you sure you want to delete "${taskType.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(taskTypeNotifierProvider.notifier).deleteTaskType(taskType.id);
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
