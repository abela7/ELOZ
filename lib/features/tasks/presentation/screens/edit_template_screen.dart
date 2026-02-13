import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../../../data/models/task_template.dart';
import '../../../../data/models/category.dart';
import '../../../../core/models/reminder.dart';
import '../../../../core/services/reminder_manager.dart';
import '../providers/template_providers.dart';
import '../providers/category_providers.dart';
import '../providers/task_type_providers.dart';
import '../providers/tag_providers.dart';
import '../../../../core/widgets/icon_picker_widget.dart';
import '../../../../core/theme/color_schemes.dart';
import '../../../../features/notifications_hub/presentation/widgets/universal_reminder_section.dart';
import '../../notifications/task_notification_creator_context.dart';

/// Edit Template Screen
/// 
/// Used for creating new templates or editing existing ones.
class EditTemplateScreen extends ConsumerStatefulWidget {
  final TaskTemplate? template;

  const EditTemplateScreen({super.key, this.template});

  @override
  ConsumerState<EditTemplateScreen> createState() => _EditTemplateScreenState();
}

class _EditTemplateScreenState extends ConsumerState<EditTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _notesController;
  
  String? _selectedCategoryId;
  String _selectedPriority = 'Medium';
  IconData? _selectedIcon;
  TimeOfDay? _selectedDefaultTime;
  List<Reminder> _defaultReminders = [];
  List<String> _subtasks = [];
  final TextEditingController _subtaskController = TextEditingController();
  
  // Task Type (Points System)
  String? _selectedTaskTypeId;
  
  // Tags
  List<String> _tags = [];

  bool get _isEditing => widget.template != null;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _titleController = TextEditingController(text: t?.title ?? '');
    _descriptionController = TextEditingController(text: t?.description ?? '');
    _notesController = TextEditingController(text: t?.notes ?? '');
    _selectedCategoryId = t?.categoryId;
    _selectedPriority = t?.priority ?? 'Medium';
    _selectedIcon = t?.icon;
    _selectedDefaultTime = t?.defaultTime;
    final raw = (t?.defaultRemindersJson ?? '').trim();
    if (raw.isNotEmpty) {
      if (raw.startsWith('[')) {
        _defaultReminders = Reminder.decodeList(raw);
      } else {
        _defaultReminders = ReminderManager().parseReminderString(raw);
      }
    }
    _subtasks = List.from(t?.defaultSubtasks ?? []);
    _selectedTaskTypeId = t?.taskTypeId;
    _tags = List.from(t?.tags ?? []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoriesAsync = ref.watch(categoryNotifierProvider);

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(child: _buildContent(context, isDark, categoriesAsync))
          : _buildContent(context, isDark, categoriesAsync),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, AsyncValue<List<Category>> categoriesAsync) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Template' : 'New Template'),
        actions: [
          TextButton.icon(
            onPressed: _saveTemplate,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Save'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFCDAF56),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Title
            _buildSectionTitle('Template Name', Icons.title_rounded),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              decoration: _inputDecoration(
                isDark,
                hintText: 'e.g., Call Mom, Team Meeting, Workout',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a template name';
                }
                return null;
              },
              textCapitalization: TextCapitalization.sentences,
            ),
            
            const SizedBox(height: 24),
            
            // Description
            _buildSectionTitle('Description (Optional)', Icons.notes_rounded),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: _inputDecoration(
                isDark,
                hintText: 'Brief description of this task',
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            
            const SizedBox(height: 24),
            
            // Category
            _buildSectionTitle('Category', Icons.category_rounded),
            const SizedBox(height: 8),
            categoriesAsync.when(
              data: (categories) => _buildCategorySelector(context, isDark, categories),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
            
            const SizedBox(height: 24),
            
            // Task Type (Points System)
            _buildSectionTitle('Task Type (Points)', Icons.stars_rounded),
            const SizedBox(height: 8),
            _buildTaskTypeSelector(isDark),
            
            const SizedBox(height: 24),
            
            // Priority
            _buildSectionTitle('Default Priority', Icons.flag_rounded),
            const SizedBox(height: 8),
            _buildPrioritySelector(isDark),
            
            const SizedBox(height: 24),
            
            // Icon
            _buildSectionTitle('Icon', Icons.emoji_emotions_rounded),
            const SizedBox(height: 8),
            _buildIconSelector(context, isDark),
            
            const SizedBox(height: 24),
            
            // Default Time
            _buildSectionTitle('Default Time (Optional)', Icons.schedule_rounded),
            const SizedBox(height: 8),
            _buildTimeSelector(context, isDark),
            
            const SizedBox(height: 24),
            
            // Reminder
            _buildSectionTitle('Default Reminder (Optional)', Icons.notifications_rounded),
            const SizedBox(height: 8),
            _buildReminderSelector(isDark),
            
            const SizedBox(height: 24),
            
            // Tags
            _buildSectionTitle('Default Tags', Icons.label_rounded),
            const SizedBox(height: 8),
            _buildTagsEditor(isDark),
            
            const SizedBox(height: 24),
            
            // Subtasks
            _buildSectionTitle('Default Subtasks', Icons.checklist_rounded),
            const SizedBox(height: 8),
            _buildSubtasksEditor(isDark),
            
            const SizedBox(height: 24),
            
            // Notes
            _buildSectionTitle('Default Notes (Optional)', Icons.sticky_note_2_rounded),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              decoration: _inputDecoration(
                isDark,
                hintText: 'Any default notes for this task',
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            
            const SizedBox(height: 40),
            
            // Usage Stats (only for existing templates)
            if (_isEditing) ...[
              _buildUsageStats(isDark),
              const SizedBox(height: 20),
            ],
            
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFCDAF56)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(bool isDark, {String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
      filled: true,
      fillColor: isDark ? const Color(0xFF2D3139) : Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCDAF56), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildCategorySelector(BuildContext context, bool isDark, List<Category> categories) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Uncategorized option
        _CategoryChip(
          name: 'None',
          icon: Icons.folder_off_outlined,
          color: Colors.grey,
          isSelected: _selectedCategoryId == null,
          isDark: isDark,
          onTap: () => setState(() => _selectedCategoryId = null),
        ),
        ...categories.map((category) => _CategoryChip(
          name: category.name,
          icon: category.icon,
          color: category.color,
          isSelected: _selectedCategoryId == category.id,
          isDark: isDark,
          onTap: () => setState(() => _selectedCategoryId = category.id),
        )),
      ],
    );
  }

  Widget _buildPrioritySelector(bool isDark) {
    return Row(
      children: [
        _PriorityChip(
          label: 'Low',
          color: const Color(0xFF66BB6A),
          isSelected: _selectedPriority == 'Low',
          isDark: isDark,
          onTap: () => setState(() => _selectedPriority = 'Low'),
        ),
        const SizedBox(width: 8),
        _PriorityChip(
          label: 'Medium',
          color: const Color(0xFFFFA726),
          isSelected: _selectedPriority == 'Medium',
          isDark: isDark,
          onTap: () => setState(() => _selectedPriority = 'Medium'),
        ),
        const SizedBox(width: 8),
        _PriorityChip(
          label: 'High',
          color: const Color(0xFFFF5252),
          isSelected: _selectedPriority == 'High',
          isDark: isDark,
          onTap: () => setState(() => _selectedPriority = 'High'),
        ),
      ],
    );
  }

  Widget _buildIconSelector(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        final selectedIcon = await showDialog<IconData>(
          context: context,
          builder: (context) => IconPickerWidget(
            selectedIcon: _selectedIcon ?? Icons.task_rounded,
            isDark: isDark,
          ),
        );
        if (selectedIcon != null) {
          setState(() => _selectedIcon = selectedIcon);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFCDAF56).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _selectedIcon ?? Icons.task_alt_rounded,
                color: const Color(0xFFCDAF56),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _selectedIcon != null ? 'Custom Icon' : 'Tap to select icon',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: _selectedDefaultTime ?? TimeOfDay.now(),
        );
        if (time != null) {
          setState(() => _selectedDefaultTime = time);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time_rounded,
              color: _selectedDefaultTime != null ? const Color(0xFFCDAF56) : (isDark ? Colors.white38 : Colors.black38),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _selectedDefaultTime != null
                    ? _selectedDefaultTime!.format(context)
                    : 'No default time',
                style: TextStyle(
                  color: _selectedDefaultTime != null
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.white54 : Colors.black54),
                ),
              ),
            ),
            if (_selectedDefaultTime != null)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => setState(() => _selectedDefaultTime = null),
                visualDensity: VisualDensity.compact,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderSelector(bool isDark) {
    if (widget.template == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.notifications_rounded, size: 20, color: AppColorSchemes.primaryGold),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Add reminders after saving the template',
                style: TextStyle(
                  fontSize: 14,
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return UniversalReminderSection(
      creatorContext: TaskNotificationCreatorContext.forTemplate(
        templateId: widget.template!.id,
        templateTitle: widget.template!.title,
      ),
      isDark: isDark,
      onRemindersChanged: () => setState(() {}),
    );
  }

  Widget _buildTaskTypeSelector(bool isDark) {
    final taskTypesAsync = ref.watch(taskTypeNotifierProvider);
    
    return taskTypesAsync.when(
      data: (taskTypes) {
        if (taskTypes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No task types yet. Add one in Settings > Points System.',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            ),
          );
        }
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            // None option
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTaskTypeId = null);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTaskTypeId == null
                      ? Colors.grey.withOpacity(0.2)
                      : (isDark ? const Color(0xFF2D3139) : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedTaskTypeId == null ? Colors.grey : (isDark ? Colors.white12 : Colors.black12),
                    width: _selectedTaskTypeId == null ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.remove_circle_outline_rounded,
                      size: 18,
                      color: _selectedTaskTypeId == null ? Colors.grey : (isDark ? Colors.white54 : Colors.black45),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'None',
                      style: TextStyle(
                        color: _selectedTaskTypeId == null ? Colors.grey : (isDark ? Colors.white54 : Colors.black45),
                        fontWeight: _selectedTaskTypeId == null ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ...taskTypes.map((taskType) {
              final isSelected = _selectedTaskTypeId == taskType.id;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedTaskTypeId = isSelected ? null : taskType.id);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFCDAF56).withOpacity(0.2)
                        : (isDark ? const Color(0xFF2D3139) : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFCDAF56) : (isDark ? Colors.white12 : Colors.black12),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.stars_rounded,
                        size: 18,
                        color: isSelected ? const Color(0xFFCDAF56) : (isDark ? Colors.white54 : Colors.black45),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        taskType.name,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFFCDAF56) : (isDark ? Colors.white70 : Colors.black54),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCDAF56).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '+${taskType.rewardOnDone}',
                            style: const TextStyle(
                              color: Color(0xFFCDAF56),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }

  Widget _buildTagsEditor(bool isDark) {
    final availableTags = ref.watch(tagNotifierProvider);
    final tagController = TextEditingController();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Available tags (pre-made tags from settings)
        if (availableTags.isNotEmpty) ...[
          Text(
            'Available Tags',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableTags.map((tag) {
              final isSelected = _tags.contains(tag);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isSelected) {
                      _tags.remove(tag);
                    } else {
                      _tags.add(tag);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFCDAF56).withOpacity(0.2)
                        : (isDark ? const Color(0xFF2D3139) : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFCDAF56)
                          : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(Icons.check_rounded, size: 14, color: Color(0xFFCDAF56)),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        tag,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFFCDAF56)
                              : (isDark ? Colors.white70 : Colors.black54),
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        
        // Selected tags
        if (_tags.isNotEmpty) ...[
          Text(
            'Selected Tags',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFCDAF56).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCDAF56)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tag,
                      style: const TextStyle(
                        color: Color(0xFFCDAF56),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _tags.remove(tag));
                      },
                      child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFCDAF56)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        
        // Add new tag
        TextField(
          controller: tagController,
          decoration: InputDecoration(
            hintText: 'Add a new tag and press Enter',
            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400),
            filled: true,
            fillColor: isDark ? const Color(0xFF2D3139) : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCDAF56), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            prefixIcon: const Icon(Icons.add_rounded, color: Color(0xFFCDAF56), size: 20),
          ),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          onSubmitted: (value) {
            final tag = value.trim().toLowerCase();
            if (tag.isNotEmpty && !_tags.contains(tag)) {
              HapticFeedback.lightImpact();
              setState(() => _tags.add(tag));
              // Add to available tags if not already there
              if (!availableTags.contains(tag)) {
                ref.read(tagNotifierProvider.notifier).addTag(tag);
              }
            }
            tagController.clear();
          },
        ),
      ],
    );
  }

  Widget _buildSubtasksEditor(bool isDark) {
    return Column(
      children: [
        // Add subtask input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _subtaskController,
                decoration: _inputDecoration(isDark, hintText: 'Add a subtask'),
                onSubmitted: (_) => _addSubtask(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _addSubtask,
              icon: const Icon(Icons.add_rounded),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFCDAF56),
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
        
        // Subtask list
        if (_subtasks.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...List.generate(_subtasks.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_box_outline_blank_rounded,
                      size: 18,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _subtasks[index],
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => _subtasks.removeAt(index)),
                      visualDensity: VisualDensity.compact,
                      color: Colors.red[400],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  void _addSubtask() {
    final text = _subtaskController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _subtasks.add(text);
        _subtaskController.clear();
      });
    }
  }

  Widget _buildUsageStats(bool isDark) {
    final template = widget.template!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFCDAF56).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bar_chart_rounded, size: 18, color: Color(0xFFCDAF56)),
                    const SizedBox(width: 8),
                    Text(
                      'Usage Statistics',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StatBadge(
                      icon: Icons.play_arrow_rounded,
                      label: '${template.usageCount} uses',
                      color: const Color(0xFFCDAF56),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 16),
                    _StatBadge(
                      icon: Icons.schedule_rounded,
                      label: template.lastUsedAgo,
                      color: isDark ? Colors.white54 : Colors.black54,
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();

    final template = TaskTemplate(
      id: widget.template?.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      categoryId: _selectedCategoryId,
      priority: _selectedPriority,
      iconCodePoint: _selectedIcon?.codePoint,
      iconFontFamily: _selectedIcon?.fontFamily,
      iconFontPackage: _selectedIcon?.fontPackage,
      defaultTimeHour: _selectedDefaultTime?.hour,
      defaultTimeMinute: _selectedDefaultTime?.minute,
      defaultRemindersJson: _defaultReminders.isEmpty ? null : Reminder.encodeList(_defaultReminders),
      defaultSubtasks: _subtasks.isEmpty ? null : _subtasks,
      tags: _tags.isEmpty ? null : _tags,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      taskTypeId: _selectedTaskTypeId,
      usageCount: widget.template?.usageCount ?? 0,
      lastUsedAt: widget.template?.lastUsedAt,
      createdAt: widget.template?.createdAt,
      usageHistory: widget.template?.usageHistory, // Preserve usage history!
    );

    final notifier = ref.read(templateNotifierProvider.notifier);
    
    if (_isEditing) {
      await notifier.updateTemplate(template);
    } else {
      await notifier.addTemplate(template);
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Template updated' : 'Template created'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// Category Chip Widget
class _CategoryChip extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.name,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : (isDark ? const Color(0xFF2D3139) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : (isDark ? Colors.white54 : Colors.black54)),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                color: isSelected ? color : (isDark ? Colors.white70 : Colors.black54),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Priority Chip Widget
class _PriorityChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _PriorityChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : (isDark ? const Color(0xFF2D3139) : Colors.grey[100]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : (isDark ? Colors.white12 : Colors.black12),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? color : (isDark ? Colors.white70 : Colors.black54),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

/// Stat Badge Widget
class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  const _StatBadge({
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
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
