import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../data/models/task.dart';
import '../../../../data/models/subtask.dart';
import '../../../../core/models/notification_settings.dart';
import '../../../../core/models/reminder.dart';
import '../../../../core/providers/notification_settings_provider.dart';
import '../../../../core/services/reminder_manager.dart';
import '../providers/add_task_provider.dart';
import '../providers/task_providers.dart';
import '../providers/category_providers.dart';
import '../providers/task_type_providers.dart';
import '../providers/tag_providers.dart';
import '../../../../core/widgets/icon_picker_widget.dart';
import '../widgets/enhanced_recurrence_selector.dart';
import '../../../../features/notifications_hub/presentation/widgets/universal_reminder_section.dart';
import '../../notifications/task_notification_creator_context.dart';
import '../../../../core/models/recurrence_rule.dart';

/// Edit Task Screen - Mirrors Add Task Screen exactly
class EditTaskScreen extends ConsumerStatefulWidget {
  final Task task;

  const EditTaskScreen({
    super.key,
    required this.task,
  });

  @override
  ConsumerState<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends ConsumerState<EditTaskScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _notesController;
  late final TextEditingController _subtaskController;
  final _titleFocusNode = FocusNode();

  // Quiet hours warning note state
  bool _dismissedQuietHoursNote = false;
  String? _quietHoursNoteKey;
  
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  IconData? _selectedIcon;
  
  // Routine done date/time (when task was actually completed)
  late DateTime _routineDoneDate;
  late TimeOfDay _routineDoneTime;
  
  // Collapsible sections
  bool _showDescription = false;
  bool _showSubtasks = false;
  bool _showNotes = false;
  bool _showReminder = false;
  bool _showRepeat = false;
  bool _showWhen = false;
  
  // Track selected "When" option for visual feedback
  int? _selectedWhenMinutes;
  
  // Subtasks list
  List<String> _subtasks = [];
  
  // Tags list
  List<String> _tags = [];
  
  // Recurrence
  RecurrenceRule? _selectedRecurrence;

  /// Check if task is in a completed/finalized state where certain fields should be locked
  bool get _isTaskLocked => 
      widget.task.status == 'completed' || widget.task.status == 'not_done';

  /// Fields that are locked for completed tasks:
  /// - Task Type (points) - can't change rewards after completion
  /// - Subtasks - can't add/remove/toggle after main task is done
  /// - Priority - shouldn't change priority after completion
  /// - Due Date/Time - historical record should be preserved

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing task data
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(text: widget.task.description ?? '');
    _notesController = TextEditingController(text: widget.task.notes ?? '');
    _subtaskController = TextEditingController();
    
    _selectedDate = widget.task.dueDate;
    _selectedTime = widget.task.dueTime ?? TimeOfDay.now();
    _selectedIcon = widget.task.icon;
    
    // Initialize routine fields
    _routineDoneDate = widget.task.completedAt ?? DateTime.now();
    _routineDoneTime = widget.task.completedAt != null 
        ? TimeOfDay.fromDateTime(widget.task.completedAt!)
        : TimeOfDay.now();
    
    _subtasks = widget.task.subtasks?.map((s) => s.title).toList() ?? [];
    _tags = widget.task.tags ?? [];
    _selectedRecurrence = widget.task.recurrence;
    
    // Show sections if they have content
    _showDescription = widget.task.description != null && widget.task.description!.isNotEmpty;
    _showSubtasks = _subtasks.isNotEmpty;
    _showNotes = widget.task.notes != null && widget.task.notes!.isNotEmpty;
    _showRepeat = _selectedRecurrence != null;
    _showReminder = (widget.task.remindersJson ?? '').trim().isNotEmpty;
    
    // Initialize form state with task values
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(addTaskFormProvider.notifier);
      notifier.setPriority(widget.task.priority);
      notifier.setCategoryId(widget.task.categoryId);
      notifier.setTaskTypeId(widget.task.taskTypeId);
      notifier.setIsRoutine(widget.task.isRoutineTask);
      notifier.setRoutineStatus(widget.task.routineStatus);
      notifier.setIsRoutineActive(widget.task.isRoutineActive);
      notifier.setIsSpecial(widget.task.isSpecial);
      final raw = (widget.task.remindersJson ?? '').trim();
      if (raw.isNotEmpty) {
        if (raw.startsWith('[')) {
          notifier.setReminders(Reminder.decodeList(raw));
        } else {
          // Legacy stored string -> parse using ReminderManager for migration.
          notifier.setReminders(ReminderManager().parseReminderString(raw));
        }
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _subtaskController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    HapticFeedback.selectionClick();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xFFCDAF56),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    HapticFeedback.selectionClick();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xFFCDAF56),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  void _addSubtask() {
    if (_subtaskController.text.trim().isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _subtasks.add(_subtaskController.text.trim());
        _subtaskController.clear();
      });
    }
  }

  void _removeSubtask(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _subtasks.removeAt(index);
    });
  }

  void _showIconPicker(BuildContext context) async {
    HapticFeedback.selectionClick();
    final icon = await showDialog<IconData>(
      context: context,
      builder: (context) => IconPickerWidget(
        selectedIcon: _selectedIcon ?? Icons.task_rounded,
        isDark: Theme.of(context).brightness == Brightness.dark,
      ),
    );
    if (icon != null) {
      setState(() => _selectedIcon = icon);
    }
  }

  Future<void> _saveTask(BuildContext context, AddTaskFormState formState) async {
    if (_titleController.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      AppSnackbar.showError(context, 'Please enter a task title');
      return;
    }
    
    // VALIDATION: Task type is mandatory for the points system
    if (formState.taskTypeId == null) {
      HapticFeedback.heavyImpact();
      AppSnackbar.showError(context, 'Please select a task type for the points system');
      return;
    }

    // Validation for routine status
    if (formState.isRoutine) {
      if (formState.routineStatus == 'planned') {
        final taskDateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
        if (taskDateTime.isBefore(DateTime.now())) {
          HapticFeedback.heavyImpact();
          AppSnackbar.showError(context, 'Planned routines cannot be in the past.');
          return;
        }
      }
    }

    HapticFeedback.mediumImpact();

    // Determine status and dates based on routine status
    String taskStatus = widget.task.status;
    DateTime? completedAt = widget.task.completedAt;
    String? notDoneReason = widget.task.notDoneReason;
    int pointsEarned = widget.task.pointsEarned;
    
    DateTime finalDueDate = _selectedDate;
    TimeOfDay finalDueTime = _selectedTime;
    
    if (formState.isRoutine) {
      if (formState.routineStatus == 'done') {
        taskStatus = 'completed';
        finalDueDate = _routineDoneDate;
        finalDueTime = _routineDoneTime;
        
        completedAt = DateTime(
          _routineDoneDate.year,
          _routineDoneDate.month,
          _routineDoneDate.day,
          _routineDoneTime.hour,
          _routineDoneTime.minute,
        );
        
        // Award points based on task type (if not already awarded)
        if (widget.task.status != 'completed' && formState.taskTypeId != null) {
          final taskTypesAsync = ref.read(taskTypeNotifierProvider);
          taskTypesAsync.whenData((types) {
            final taskType = types.firstWhere(
              (t) => t.id == formState.taskTypeId,
              orElse: () => types.first,
            );
            pointsEarned = taskType.rewardOnDone;
          });
        }
      } else if (formState.routineStatus == 'planned') {
        taskStatus = 'pending';
        finalDueDate = _selectedDate;
        finalDueTime = _selectedTime;
        completedAt = null;
        notDoneReason = null;
        if (widget.task.status == 'completed' || widget.task.status == 'not_done') {
          pointsEarned = 0;
        }
      }
    }

    // Create updated task with all fields
    final updatedTask = widget.task.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      dueDate: finalDueDate,
      dueTime: finalDueTime,
      priority: formState.priority,
      categoryId: formState.categoryId,
      taskTypeId: formState.taskTypeId,
      subtasks: _subtasks.isEmpty
          ? null
          : _subtasks.map((title) => Subtask(title: title)).toList(),
      recurrence: _selectedRecurrence,
      remindersJson: widget.task.remindersJson,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      iconCodePoint: _selectedIcon?.codePoint,
      iconFontFamily: _selectedIcon?.fontFamily,
      iconFontPackage: _selectedIcon?.fontPackage,
      tags: _tags.isEmpty ? null : _tags,
      isRoutine: formState.isRoutine,
      routineStatus: formState.routineStatus,
      isRoutineActive: formState.isRoutineActive,
      isSpecial: formState.isSpecial,
      status: taskStatus,
      completedAt: completedAt,
      notDoneReason: notDoneReason,
      pointsEarned: pointsEarned,
      taskKind: formState.isRoutine 
          ? TaskKind.routine 
          : (_selectedRecurrence != null ? TaskKind.recurring : TaskKind.normal),
    );

    // Update task
    final notifier = ref.read(taskNotifierProvider.notifier);
    await notifier.updateTask(updatedTask);

    // Invalidate providers
    ref.invalidate(taskNotifierProvider);
    final taskDate = DateTime(updatedTask.dueDate.year, updatedTask.dueDate.month, updatedTask.dueDate.day);
    ref.invalidate(tasksForDateProvider(taskDate));
    
    final originalDate = DateTime(widget.task.dueDate.year, widget.task.dueDate.month, widget.task.dueDate.day);
    if (originalDate != taskDate) {
      ref.invalidate(tasksForDateProvider(originalDate));
    }
    
    if (formState.isRoutine) {
      ref.invalidate(allRoutinesProvider);
      final routineGroupId = updatedTask.effectiveRoutineGroupId;
      ref.invalidate(routineStatsProvider(routineGroupId));
      ref.invalidate(routineGroupProvider(routineGroupId));
    }

    if (mounted) {
      String message;
      if (formState.isRoutine) {
        switch (formState.routineStatus) {
          case 'done':
            message = 'Routine completed! +$pointsEarned points';
            break;
          case 'skipped':
            message = 'Routine marked as skipped';
            break;
          default:
            message = 'Routine updated!';
        }
      } else {
        message = 'Task updated successfully';
      }
      AppSnackbar.showSuccess(context, message);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formState = ref.watch(addTaskFormProvider);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF1A1D23) : Colors.grey.shade50,
        body: isDark
            ? DarkGradient.wrap(child: _buildBody(context, isDark, formState))
            : _buildBody(context, isDark, formState),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isDark, AddTaskFormState formState) {
    return SafeArea(
      child: Column(
        children: [
          _buildAppBar(context, isDark, formState),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Warning banner for completed/not_done tasks
                  if (_isTaskLocked)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.withOpacity(isDark ? 0.15 : 0.1),
                            Colors.orange.withOpacity(isDark ? 0.08 : 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.orange.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.lock_rounded, color: Colors.orange.shade700, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Limited Editing Mode',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.task.status == 'completed'
                                      ? 'This task is completed. Points and subtasks are locked.'
                                      : 'This task is marked as not done. Points and subtasks are locked.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Title Input
                  _buildTitleInput(context, isDark),
                  const SizedBox(height: 10),
                  
                  // Description (Accordion - under title, before icon)
                  _buildDescriptionAccordion(context, isDark),
                  const SizedBox(height: 10),
                  
                  // Icon Selection
                  _buildIconSelection(context, isDark),
                  const SizedBox(height: 14),
                  
                  // When? Accordion (Hidden if in Routine Mode or task is locked)
                  if (!formState.isRoutine && !_isTaskLocked) ...[
                    _buildWhenAccordion(context, isDark),
                    const SizedBox(height: 12),
                  ],
                  
                  // Quick Date Buttons (Hidden if in Routine Mode)
                  if (!formState.isRoutine) ...[
                    _buildQuickDateButtons(context, isDark),
                    const SizedBox(height: 12),
                  ],
                  
                  // Date & Time Row (Hidden if in Routine Mode)
                  if (!formState.isRoutine) ...[
                    _buildDateTimeRow(context, isDark),
                    const SizedBox(height: 18),
                  ],
                  
                  // Priority Section
                  _buildPrioritySection(context, isDark, formState),
                  const SizedBox(height: 18),
                  
                  // Category Section
                  _buildCategorySection(context, isDark, formState),
                  const SizedBox(height: 18),
                  
                  // Task Type Section
                  _buildTaskTypeSection(context, isDark, formState),
                  const SizedBox(height: 18),
                  
                  // Routine Mode Toggle (hidden if recurrence is set)
                  if (_selectedRecurrence == null) ...[
                    _buildRoutineToggle(context, isDark, formState),
                    const SizedBox(height: 18),
                  ],
                  
                  // Tags Section
                  _buildTagsSection(context, isDark),
                  const SizedBox(height: 18),
                  
                  // Recurrence Section (accordion, hidden if routine mode is on)
                  if (!formState.isRoutine) ...[
                    _buildRepeatAccordion(context, isDark),
                    const SizedBox(height: 18),
                  ],
                  
                  // Reminder Section (Accordion)
                  _buildReminderAccordion(context, isDark, formState),
                  const SizedBox(height: 18),
                  
                  // Expandable Sections
                  _buildExpandableSection(
                    context: context,
                    isDark: isDark,
                    title: 'Subtasks',
                    icon: Icons.checklist_rounded,
                    isExpanded: _showSubtasks,
                    onToggle: () => setState(() => _showSubtasks = !_showSubtasks),
                    badge: _subtasks.isNotEmpty ? _subtasks.length.toString() : null,
                    child: _buildSubtasksSection(isDark),
                  ),
                  const SizedBox(height: 8),
                  
                  _buildExpandableSection(
                    context: context,
                    isDark: isDark,
                    title: 'Notes',
                    icon: Icons.sticky_note_2_rounded,
                    isExpanded: _showNotes,
                    onToggle: () => setState(() => _showNotes = !_showNotes),
                    child: _buildNotesField(isDark),
                  ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark, AddTaskFormState formState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? Colors.white : Colors.black87,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Edit Task',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _saveTask(context, formState),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFCDAF56), Color(0xFFB8982E)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFCDAF56).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, color: Colors.black87, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleInput(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF3E4148) : Colors.grey.shade200,
        ),
      ),
      child: TextField(
        controller: _titleController,
        focusNode: _titleFocusNode,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: 'What needs to be done?',
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : Colors.grey.shade400,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 14, right: 10),
            child: Icon(Icons.edit_rounded, color: Color(0xFFCDAF56), size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 44),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }

  Widget _buildDescriptionAccordion(BuildContext context, bool isDark) {
    final hasDescription = _descriptionController.text.isNotEmpty;
    
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _showDescription = !_showDescription);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D3139) : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _showDescription
                    ? const Color(0xFFCDAF56).withValues(alpha: 0.5)
                    : (isDark ? Colors.white12 : Colors.black12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.notes_rounded, color: Color(0xFFCDAF56), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (hasDescription && !_showDescription)
                        Text(
                          _descriptionController.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _showDescription ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: isDark ? Colors.white54 : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D3139) : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              child: TextField(
                controller: _descriptionController,
                maxLines: 3,
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Add more details...',
                  hintStyle: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.grey.shade400),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          crossFadeState: _showDescription ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildIconSelection(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => _showIconPicker(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF3E4148) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _selectedIcon != null
                    ? const Color(0xFFCDAF56).withValues(alpha: 0.15)
                    : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _selectedIcon ?? Icons.add_rounded,
                color: _selectedIcon != null
                    ? const Color(0xFFCDAF56)
                    : (isDark ? Colors.white54 : Colors.grey.shade400),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Task Icon',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    _selectedIcon != null ? 'Tap to change' : 'Tap to select',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white54 : Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDateButtons(BuildContext context, bool isDark) {
    final today = DateTime.now();
    final isToday = _isSameDay(_selectedDate, today);
    final isTomorrow = _isSameDay(_selectedDate, today.add(const Duration(days: 1)));
    final isNextWeek = _isSameDay(_selectedDate, today.add(const Duration(days: 7)));

    return Row(
      children: [
        _QuickDateChip(
          label: 'Today',
          icon: Icons.today_rounded,
          isSelected: isToday,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedDate = today);
          },
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _QuickDateChip(
          label: 'Tomorrow',
          icon: Icons.wb_sunny_rounded,
          isSelected: isTomorrow,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedDate = today.add(const Duration(days: 1)));
          },
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _QuickDateChip(
          label: 'Next Week',
          icon: Icons.date_range_rounded,
          isSelected: isNextWeek,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedDate = today.add(const Duration(days: 7)));
          },
          isDark: isDark,
        ),
      ],
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  Widget _buildDateTimeRow(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Lock notice for completed tasks
        if (_isTaskLocked)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(isDark ? 0.1 : 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_rounded, size: 14, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Date/time locked after completion (historical record)',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
        IgnorePointer(
          ignoring: _isTaskLocked,
          child: Opacity(
            opacity: _isTaskLocked ? 0.5 : 1.0,
            child: Row(
              children: [
                Expanded(
                  child: _ModernPickerTile(
                    icon: _isTaskLocked ? Icons.lock_clock : Icons.calendar_month_rounded,
                    label: 'Date',
                    value: DateFormat('MMM d').format(_selectedDate),
                    onTap: _isTaskLocked ? () {} : () => _selectDate(context),
                    isDark: isDark,
                    color: _isTaskLocked ? Colors.grey : const Color(0xFF4ECDC4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ModernPickerTile(
                    icon: _isTaskLocked ? Icons.lock_clock : Icons.schedule_rounded,
                    label: 'Time',
                    value: _selectedTime.format(context),
                    onTap: _isTaskLocked ? () {} : () => _selectTime(context),
                    isDark: isDark,
                    color: _isTaskLocked ? Colors.grey : const Color(0xFFFFB347),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Apply a quick "When?" duration from now
  void _applyWhenDuration(int minutes, {bool isCustom = false}) {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final targetTime = now.add(Duration(minutes: minutes));
    setState(() {
      _selectedDate = DateTime(targetTime.year, targetTime.month, targetTime.day);
      _selectedTime = TimeOfDay(hour: targetTime.hour, minute: targetTime.minute);
      _selectedWhenMinutes = isCustom ? -1 : minutes; // -1 indicates custom
    });
  }

  /// Show custom duration picker for "When?" section
  Future<void> _showCustomWhenPicker(BuildContext context, bool isDark) async {
    int customHours = 0;
    int customMinutes = 30;
    
    final result = await showModalBottomSheet<Map<String, int>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final now = DateTime.now();
          final previewTime = now.add(Duration(hours: customHours, minutes: customMinutes));
          final previewText = DateFormat('EEE, MMM d · h:mm a').format(previewTime);
          final durationText = customHours > 0 
              ? '${customHours}h ${customMinutes}m' 
              : '${customMinutes}m';
          
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 16,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D23) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Title
                Text(
                  'Set Duration',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'How long from now?',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 28),
                
                // Hours control
                _buildDurationControl(
                  context: context,
                  isDark: isDark,
                  label: 'Hours',
                  value: customHours,
                  maxValue: 23,
                  onDecrease: () {
                    if (customHours > 0) setModalState(() => customHours--);
                  },
                  onIncrease: () {
                    if (customHours < 23) setModalState(() => customHours++);
                  },
                ),
                const SizedBox(height: 16),
                
                // Minutes control
                _buildDurationControl(
                  context: context,
                  isDark: isDark,
                  label: 'Minutes',
                  value: customMinutes,
                  maxValue: 59,
                  onDecrease: () {
                    if (customMinutes > 0) setModalState(() => customMinutes--);
                  },
                  onIncrease: () {
                    if (customMinutes < 59) setModalState(() => customMinutes++);
                  },
                ),
                const SizedBox(height: 24),
                
                // Preview card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [const Color(0xFF2A2F38), const Color(0xFF252A32)]
                          : [Colors.grey.shade50, Colors.grey.shade100],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFCDAF56).withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCDAF56).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.event_available_rounded,
                          color: Color(0xFFCDAF56),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'In $durationText',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFCDAF56),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              previewText,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Confirm button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (customHours == 0 && customMinutes == 0)
                        ? null
                        : () => Navigator.pop(context, {'hours': customHours, 'minutes': customMinutes}),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCDAF56),
                      foregroundColor: Colors.black87,
                      disabledBackgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Set Time',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    
    if (result != null) {
      final totalMinutes = (result['hours']! * 60) + result['minutes']!;
      _applyWhenDuration(totalMinutes, isCustom: true);
    }
  }

  /// Build a simple +/- duration control widget
  Widget _buildDurationControl({
    required BuildContext context,
    required bool isDark,
    required String label,
    required int value,
    required int maxValue,
    required VoidCallback onDecrease,
    required VoidCallback onIncrease,
  }) {
    const accentColor = Color(0xFFCDAF56);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const Spacer(),
          // Decrease button
          GestureDetector(
            onTap: onDecrease,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: value > 0
                    ? accentColor.withOpacity(0.15)
                    : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.remove_rounded,
                color: value > 0
                    ? accentColor
                    : (isDark ? Colors.white24 : Colors.grey.shade400),
                size: 20,
              ),
            ),
          ),
          // Value display
          Container(
            width: 60,
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          // Increase button
          GestureDetector(
            onTap: onIncrease,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: value < maxValue
                    ? accentColor.withOpacity(0.15)
                    : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.add_rounded,
                color: value < maxValue
                    ? accentColor
                    : (isDark ? Colors.white24 : Colors.grey.shade400),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhenAccordion(BuildContext context, bool isDark) {
    const accentColor = Color(0xFFCDAF56);
    
    return Column(
      children: [
        // Accordion Header
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _showWhen = !_showWhen);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D3139) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showWhen
                    ? accentColor.withOpacity(0.5)
                    : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.timer_rounded,
                    size: 16,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'When?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'Quick time selection',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _showWhen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Expanded Content
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildWhenContent(context, isDark),
          ),
          crossFadeState: _showWhen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildWhenContent(BuildContext context, bool isDark) {
    const accentColor = Color(0xFFCDAF56);
    final isCustomSelected = _selectedWhenMinutes == -1;
    
    // Quick time options
    final quickOptions = [
      {'label': '1 min', 'minutes': 1},
      {'label': '5 min', 'minutes': 5},
      {'label': '10 min', 'minutes': 10},
      {'label': '15 min', 'minutes': 15},
      {'label': '30 min', 'minutes': 30},
      {'label': '1 hr', 'minutes': 60},
    ];
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252830) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick options grid
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...quickOptions.map((option) => _buildWhenChip(
                label: option['label'] as String,
                minutes: option['minutes'] as int,
                isDark: isDark,
                isSelected: _selectedWhenMinutes == option['minutes'],
              )),
              // Custom option
              GestureDetector(
                onTap: () => _showCustomWhenPicker(context, isDark),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isCustomSelected
                        ? accentColor.withOpacity(0.15)
                        : (isDark ? const Color(0xFF2D3139) : Colors.white),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isCustomSelected
                          ? accentColor
                          : (isDark ? Colors.white12 : Colors.grey.shade300),
                      width: isCustomSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 14,
                        color: isCustomSelected
                            ? accentColor
                            : (isDark ? Colors.white54 : Colors.grey.shade600),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Custom',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isCustomSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isCustomSelected
                              ? accentColor
                              : (isDark ? Colors.white70 : Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 14),
          
          // Preview of current selection
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(isDark ? 0.1 : 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_rounded,
                  size: 16,
                  color: accentColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Task due: ${DateFormat('MMM d, yyyy · h:mm a').format(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute))}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhenChip({
    required String label,
    required int minutes,
    required bool isDark,
    required bool isSelected,
  }) {
    const accentColor = Color(0xFFCDAF56);
    
    return GestureDetector(
      onTap: () => _applyWhenDuration(minutes),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withOpacity(0.15)
              : (isDark ? const Color(0xFF2D3139) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? accentColor
                : (isDark ? Colors.white70 : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }

  Widget _buildPrioritySection(BuildContext context, bool isDark, AddTaskFormState formState) {
    const accentGold = Color(0xFFCDAF56);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SectionHeader(icon: Icons.flag_rounded, title: 'Priority', isDark: isDark),
            if (_isTaskLocked) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 12, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Locked',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        IgnorePointer(
          ignoring: _isTaskLocked,
          child: Opacity(
            opacity: _isTaskLocked ? 0.5 : 1.0,
            child: Row(
              children: [
                Expanded(
                  child: _ModernPriorityChip(
                    label: 'Low',
                    icon: Icons.keyboard_arrow_down_rounded,
                    color: _isTaskLocked ? Colors.grey : const Color(0xFF4ECDC4),
                    isSelected: formState.priority == 'Low',
                    onTap: _isTaskLocked ? () {} : () => ref.read(addTaskFormProvider.notifier).setPriority('Low'),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ModernPriorityChip(
                    label: 'Medium',
                    icon: Icons.remove_rounded,
                    color: _isTaskLocked ? Colors.grey : const Color(0xFFFFB347),
                    isSelected: formState.priority == 'Medium',
                    onTap: _isTaskLocked ? () {} : () => ref.read(addTaskFormProvider.notifier).setPriority('Medium'),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ModernPriorityChip(
                    label: 'High',
                    icon: Icons.keyboard_arrow_up_rounded,
                    color: _isTaskLocked ? Colors.grey : const Color(0xFFFF6B6B),
                    isSelected: formState.priority == 'High',
                    onTap: _isTaskLocked ? () {} : () => ref.read(addTaskFormProvider.notifier).setPriority('High'),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Special Task Toggle (compact) - NOT locked (cosmetic, can change anytime)
        GestureDetector(
          onTap: () => ref.read(addTaskFormProvider.notifier).setIsSpecial(!formState.isSpecial),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D3139) : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: formState.isSpecial 
                    ? accentGold
                    : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
                width: formState.isSpecial ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  formState.isSpecial ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 18,
                  color: formState.isSpecial ? accentGold : (isDark ? Colors.white54 : Colors.black45),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Special Task',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: formState.isSpecial,
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    ref.read(addTaskFormProvider.notifier).setIsSpecial(value);
                  },
                  activeThumbColor: accentGold,
                  activeTrackColor: accentGold.withValues(alpha: 0.3),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection(BuildContext context, bool isDark, AddTaskFormState formState) {
    final categoriesAsync = ref.watch(categoryNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(icon: Icons.category_rounded, title: 'Category', isDark: isDark),
        const SizedBox(height: 12),
        categoriesAsync.when(
          data: (categories) {
            if (categories.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No categories yet. Add one in Settings.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              );
            }
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: categories.map((category) {
                final isSelected = formState.categoryId == category.id;
                return _ModernChip(
                  iconData: category.icon,
                  label: category.name,
                  color: category.color,
                  isSelected: isSelected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(addTaskFormProvider.notifier).setCategoryId(
                          isSelected ? null : category.id,
                        );
                  },
                  isDark: isDark,
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Error loading categories',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskTypeSection(BuildContext context, bool isDark, AddTaskFormState formState) {
    final taskTypesAsync = ref.watch(taskTypeNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SectionHeader(icon: Icons.layers_rounded, title: 'Task Level', isDark: isDark, isRequired: true),
            if (_isTaskLocked) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 12, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Locked',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // Show locked message for completed tasks
        if (_isTaskLocked)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(isDark ? 0.1 : 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Task level cannot be changed after task is completed.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        taskTypesAsync.when(
          data: (taskTypes) {
            if (taskTypes.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No task levels yet. Add one in Settings > Task Levels.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              );
            }
            return IgnorePointer(
              ignoring: _isTaskLocked,
              child: Opacity(
                opacity: _isTaskLocked ? 0.5 : 1.0,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: taskTypes.map((taskType) {
                    final isSelected = formState.taskTypeId == taskType.id;
                    final color = taskType.colorValue != null ? Color(taskType.colorValue!) : const Color(0xFFCDAF56);
                    return _ModernChip(
                      iconData: taskType.iconCode != null
                          ? IconData(taskType.iconCode!, fontFamily: 'MaterialIcons')
                          : Icons.star_rounded,
                      label: taskType.name,
                      color: color,
                      isSelected: isSelected,
                      onTap: () {
                        if (_isTaskLocked) return;
                        HapticFeedback.selectionClick();
                        ref.read(addTaskFormProvider.notifier).setTaskTypeId(
                              isSelected ? null : taskType.id,
                            );
                      },
                      isDark: isDark,
                    );
                  }).toList(),
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Error loading task types',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoutineToggle(BuildContext context, bool isDark, AddTaskFormState formState) {
    const accentColor = Color(0xFFCDAF56);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: formState.isRoutine
              ? accentColor
              : (isDark ? const Color(0xFF3E4148) : Colors.grey.shade200),
          width: formState.isRoutine ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.loop_rounded,
                  color: accentColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Routine Mode',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Switch.adaptive(
                value: formState.isRoutine,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  ref.read(addTaskFormProvider.notifier).setIsRoutine(value);
                  if (value && _selectedRecurrence != null) {
                    setState(() => _selectedRecurrence = null);
                  }
                },
                activeThumbColor: accentColor,
                activeTrackColor: accentColor.withValues(alpha: 0.3),
              ),
            ],
          ),
          if (formState.isRoutine) ...[
            const SizedBox(height: 16),
            
            // Routine Status Selection
            Text(
              'Initial Status',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildRoutineStatusChip(
                  context: context,
                  isDark: isDark,
                  label: 'Planned',
                  icon: Icons.schedule_rounded,
                  color: const Color(0xFFCDAF56),
                  isSelected: formState.routineStatus == 'planned',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(addTaskFormProvider.notifier).setRoutineStatus('planned');
                  },
                ),
                const SizedBox(width: 8),
                _buildRoutineStatusChip(
                  context: context,
                  isDark: isDark,
                  label: 'Done',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF4CAF50),
                  isSelected: formState.routineStatus == 'done',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(addTaskFormProvider.notifier).setRoutineStatus('done');
                  },
                ),
              ],
            ),
            
            // Show date/time pickers based on status
            if (formState.routineStatus == 'planned') ...[
              const SizedBox(height: 16),
              _buildPlannedTimeSection(context, isDark),
            ] else if (formState.routineStatus == 'done') ...[
              const SizedBox(height: 16),
              _buildDoneTimeSection(context, isDark),
            ],
            
            const SizedBox(height: 16),
            
            // Info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.1 : 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: accentColor.withValues(alpha: 0.8), size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Perfect for tasks like haircuts, dentist visits, car maintenance.',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey.shade700, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoutineStatusChip({
    required BuildContext context,
    required bool isDark,
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.15)
                : (isDark ? Colors.black26 : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : (isDark ? Colors.white54 : Colors.grey), size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? color : (isDark ? Colors.white54 : Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlannedTimeSection(BuildContext context, bool isDark) {
    final dateFormat = DateFormat('MMM d');
    const accentColor = Color(0xFFCDAF56);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.1 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, color: accentColor, size: 16),
              const SizedBox(width: 8),
              Text('Schedule your routine', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D3139) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 16, color: accentColor),
                        const SizedBox(width: 8),
                        Text(dateFormat.format(_selectedDate), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _selectTime(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D3139) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 16, color: accentColor),
                      const SizedBox(width: 8),
                      Text(_selectedTime.format(context), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoneTimeSection(BuildContext context, bool isDark) {
    final dateFormat = DateFormat('MMM d');
    const greenColor = Color(0xFF4CAF50);
    final today = DateTime.now();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: greenColor.withValues(alpha: isDark ? 0.1 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: greenColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: greenColor, size: 16),
              const SizedBox(width: 8),
              Text('When was it completed?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickDoneDateChip('Today', today, isDark),
                const SizedBox(width: 8),
                _buildQuickDoneDateChip('Yesterday', today.subtract(const Duration(days: 1)), isDark),
                const SizedBox(width: 8),
                _buildQuickDoneDateChip('2 Days Ago', today.subtract(const Duration(days: 2)), isDark),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: _routineDoneDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                    if (picked != null) {
                      setState(() => _routineDoneDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D3139) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 16, color: greenColor),
                        const SizedBox(width: 8),
                        Text(dateFormat.format(_routineDoneDate), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: _routineDoneTime);
                  if (picked != null) {
                    setState(() => _routineDoneTime = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D3139) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 16, color: greenColor),
                      const SizedBox(width: 8),
                      Text(_routineDoneTime.format(context), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDoneDateChip(String label, DateTime date, bool isDark) {
    final isSelected = _isSameDay(_routineDoneDate, date);
    const greenColor = Color(0xFF4CAF50);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _routineDoneDate = date);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? greenColor.withValues(alpha: 0.25) : (isDark ? const Color(0xFF2D3139) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? greenColor : (isDark ? Colors.white12 : Colors.grey.shade300)),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? greenColor : (isDark ? Colors.white70 : Colors.grey.shade700))),
      ),
    );
  }

  Widget _buildTagsSection(BuildContext context, bool isDark) {
    final availableTags = ref.watch(tagNotifierProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(icon: Icons.label_rounded, title: 'Tags', isDark: isDark),
        const SizedBox(height: 12),
        
        // Available tags
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
                child: Chip(
                  label: Text(tag),
                  backgroundColor: isSelected
                      ? const Color(0xFFCDAF56).withValues(alpha: 0.2)
                      : (isDark ? const Color(0xFF2D3139) : Colors.grey.shade100),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? const Color(0xFFCDAF56)
                        : (isDark ? Colors.white : Colors.black87),
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFFCDAF56)
                        : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300),
                    width: isSelected ? 2 : 1,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
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
              return Chip(
                label: Text(tag),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () {
                  HapticFeedback.lightImpact();
                  setState(() => _tags.remove(tag));
                },
                backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.grey.shade100,
                labelStyle: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 13,
                ),
                side: const BorderSide(
                  color: Color(0xFFCDAF56),
                  width: 1,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        
        // Add new tag field
        TextField(
          decoration: InputDecoration(
            hintText: 'Add a new tag...',
            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: isDark ? const Color(0xFF2D3139) : Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCDAF56), width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            prefixIcon: const Icon(Icons.add_rounded, color: Color(0xFFCDAF56), size: 18),
          ),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
          onSubmitted: (value) {
            final tag = value.trim().toLowerCase();
            if (tag.isNotEmpty && !_tags.contains(tag)) {
              HapticFeedback.lightImpact();
              setState(() => _tags.add(tag));
              if (!availableTags.contains(tag)) {
                ref.read(tagNotifierProvider.notifier).addTag(tag);
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildRepeatAccordion(BuildContext context, bool isDark) {
    final hasRecurrence = _selectedRecurrence != null;
    
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _showRepeat = !_showRepeat);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D3139) : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _showRepeat || hasRecurrence
                    ? const Color(0xFFCDAF56).withValues(alpha: 0.5)
                    : (isDark ? Colors.white12 : Colors.black12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.repeat_rounded, color: Color(0xFFCDAF56), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Repeat',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        hasRecurrence ? _selectedRecurrence!.getDescription() : 'One-time task',
                        style: TextStyle(
                          fontSize: 11,
                          color: hasRecurrence ? const Color(0xFFCDAF56) : (isDark ? Colors.white38 : Colors.grey),
                          fontWeight: hasRecurrence ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasRecurrence)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedRecurrence = null);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, size: 16, color: isDark ? Colors.white38 : Colors.grey),
                    ),
                  ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _showRepeat ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: isDark ? Colors.white54 : Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: EnhancedRecurrenceSelector(
              initialRule: _selectedRecurrence,
              taskDueDate: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute),
              onChanged: (rule) {
                setState(() => _selectedRecurrence = rule);
                if (rule != null) {
                  ref.read(addTaskFormProvider.notifier).setIsRoutine(false);
                }
              },
            ),
          ),
          crossFadeState: _showRepeat ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildReminderAccordion(BuildContext context, bool isDark, AddTaskFormState formState) {
    final settings = ref.watch(notificationSettingsProvider);
    const reminderLabel = 'Reminders';
    final dueDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final isBlockedByQuietHours = _isQuietHoursBlocked(settings, formState, dueDateTime);
    final quietHoursKey = _quietHoursBlockKey(settings, formState, dueDateTime);
    _syncQuietHoursNoteState(isBlockedByQuietHours, quietHoursKey);
    
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _showReminder = !_showReminder);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D3139) : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _showReminder
                    ? const Color(0xFFCDAF56).withValues(alpha: 0.5)
                    : (isDark ? Colors.white12 : Colors.black12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _showReminder ? Icons.notifications_active_rounded : Icons.notifications_outlined,
                  size: 18,
                  color: _showReminder
                      ? const Color(0xFFCDAF56)
                      : (isDark ? Colors.white54 : Colors.black45),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    reminderLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
                AnimatedRotation(
                    turns: _showReminder ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: [
                UniversalReminderSection(
                  creatorContext: TaskNotificationCreatorContext.forTask(
                    taskId: widget.task.id,
                    taskTitle: widget.task.title,
                  ),
                  isDark: isDark,
                  onRemindersChanged: () => setState(() {}),
                ),
                if (isBlockedByQuietHours && !_dismissedQuietHoursNote) ...[
                  const SizedBox(height: 10),
                  _buildQuietHoursBlockedNote(context, isDark),
                ],
              ],
            ),
          ),
          crossFadeState: _showReminder ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  bool _isQuietHoursBlocked(
    NotificationSettings settings,
    AddTaskFormState formState,
    DateTime dueDateTime,
  ) {
    if (!formState.isSpecial) return false;
    if (!settings.quietHoursEnabled || settings.allowUrgentDuringQuietHours) return false;
    // Quiet hours check skipped when using UniversalReminderSection (reminders in universal storage).
    return false;
  }


  String _quietHoursBlockKey(
    NotificationSettings settings,
    AddTaskFormState formState,
    DateTime dueDateTime,
  ) {
    final daysKey = settings.quietHoursDays.join(',');
    return '${dueDateTime.millisecondsSinceEpoch}|${formState.isSpecial}|'
        '${settings.quietHoursEnabled}|${settings.allowUrgentDuringQuietHours}|'
        '${settings.quietHoursStart}-${settings.quietHoursEnd}|$daysKey';
  }

  void _syncQuietHoursNoteState(bool isBlocked, String noteKey) {
    if (!isBlocked && _dismissedQuietHoursNote) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _dismissedQuietHoursNote = false;
          _quietHoursNoteKey = null;
        });
      });
      return;
    }

    if (isBlocked && _quietHoursNoteKey != noteKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _quietHoursNoteKey = noteKey;
          _dismissedQuietHoursNote = false;
        });
      });
    }
  }

  Widget _buildQuietHoursBlockedNote(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2B2433) : const Color(0xFFF7F0FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF6F5A9A) : const Color(0xFFD8C7F0),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.bedtime_rounded, color: Color(0xFF8E6BD1), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Quiet hours will block this special task reminder. Turn on "Allow Special Task Alerts" to let it ring.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : const Color(0xFF3D2C5A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _dismissedQuietHoursNote = true),
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableSection({
    required BuildContext context,
    required bool isDark,
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    String? badge,
    required Widget child,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onToggle();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D3139) : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isExpanded 
                    ? const Color(0xFFCDAF56).withValues(alpha: 0.5)
                    : (isDark ? Colors.white12 : Colors.black12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFFCDAF56), size: 16),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCDAF56),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: isDark ? Colors.white54 : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: child,
          ),
          crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildSubtasksSection(bool isDark) {
    return Column(
      children: [
        // Locked warning for completed tasks
        if (_isTaskLocked)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(isDark ? 0.1 : 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_rounded, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Subtasks cannot be modified after task is completed.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // Subtask input - disabled for completed tasks
        IgnorePointer(
          ignoring: _isTaskLocked,
          child: Opacity(
            opacity: _isTaskLocked ? 0.5 : 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D3139) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF3E4148) : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subtaskController,
                      enabled: !_isTaskLocked,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: _isTaskLocked ? 'Subtasks locked' : 'Add a subtask...',
                        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onSubmitted: _isTaskLocked ? null : (_) => _addSubtask(),
                    ),
                  ),
                  GestureDetector(
                    onTap: _isTaskLocked ? null : _addSubtask,
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isTaskLocked 
                            ? Colors.grey.withOpacity(0.3) 
                            : const Color(0xFFCDAF56),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _isTaskLocked ? Icons.lock_rounded : Icons.add_rounded, 
                        color: _isTaskLocked ? Colors.grey : Colors.black87, 
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Subtask list - show but disable remove for completed tasks
        if (_subtasks.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...List.generate(_subtasks.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D3139) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF3E4148) : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _isTaskLocked ? Colors.grey : const Color(0xFFCDAF56),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _subtasks[index],
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    // Hide remove button for completed tasks
                    if (!_isTaskLocked)
                      GestureDetector(
                        onTap: () => _removeSubtask(index),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.red.shade400,
                          size: 20,
                        ),
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

  Widget _buildNotesField(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: TextField(
        controller: _notesController,
        maxLines: 3,
        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: 'Add any additional notes...',
          hintStyle: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }
}

// ===================== HELPER WIDGETS =====================

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDark;
  final bool isRequired;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.isDark,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFCDAF56), size: 16),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Required',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickDateChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _QuickDateChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFCDAF56).withValues(alpha: 0.15)
                : (isDark ? const Color(0xFF2D3139) : Colors.grey[100]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFCDAF56)
                  : (isDark ? Colors.white12 : Colors.black12),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? const Color(0xFFCDAF56)
                    : (isDark ? Colors.white54 : Colors.grey.shade500),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFFCDAF56)
                      : (isDark ? Colors.white70 : Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModernPickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isDark;
  final Color color;

  const _ModernPickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white54 : Colors.grey.shade500,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernPriorityChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _ModernPriorityChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF2D3139) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color : (isDark ? Colors.white54 : Colors.grey.shade500),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : (isDark ? Colors.white70 : Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernChip extends StatelessWidget {
  final IconData? iconData;
  final String? emoji;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _ModernChip({
    this.iconData,
    this.emoji,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF2D3139) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconData != null)
              Icon(
                iconData,
                size: 14,
                color: isSelected ? color : (isDark ? Colors.white54 : Colors.black45),
              )
            else if (emoji != null)
              Text(emoji!, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? color : (isDark ? Colors.white70 : Colors.black54),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
