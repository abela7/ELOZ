import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../data/models/task.dart';
import '../../../../data/local/hive/hive_service.dart';
import '../../../../core/widgets/date_navigator_widget.dart';
import '../widgets/daily_points_chart.dart';
import '../widgets/hourly_productivity_chart.dart';
import '../widgets/task_heatmap.dart';
import '../widgets/pie_chart_widget.dart';
import '../widgets/task_detail_modal.dart';
import '../providers/task_providers.dart';
import 'add_task_screen.dart';

/// Provider for daily reflections
final dailyReflectionProvider = StateNotifierProvider.family<DailyReflectionNotifier, String, String>((ref, dateKey) {
  return DailyReflectionNotifier(dateKey);
});

class DailyReflectionNotifier extends StateNotifier<String> {
  final String dateKey;
  DailyReflectionNotifier(this.dateKey) : super('') {
    _load();
  }

  void _load() {
    final box = HiveService.box;
    state = box.get('reflection_$dateKey', defaultValue: '') as String;
  }

  Future<void> save(String content) async {
    final box = HiveService.box;
    await box.put('reflection_$dateKey', content);
    state = content;
  }
}

/// Reflection Detail & Editor Screen - Full Screen Mode
class ReflectionDetailScreen extends ConsumerStatefulWidget {
  final DateTime date;
  final bool isEditing;

  const ReflectionDetailScreen({
    super.key,
    required this.date,
    this.isEditing = false,
  });

  @override
  ConsumerState<ReflectionDetailScreen> createState() => _ReflectionDetailScreenState();
}

class _ReflectionDetailScreenState extends ConsumerState<ReflectionDetailScreen> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _mentionOverlay;
  late bool _isEditing;
  late String _initialText;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.isEditing;
    final dateKey = DateFormat('yyyy-MM-dd').format(widget.date);
    _initialText = ref.read(dailyReflectionProvider(dateKey));
    _controller = TextEditingController(text: _initialText);
    _focusNode = FocusNode();
    _controller.addListener(_onTextChanged);
    
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _hideMentionOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    final selection = _controller.selection;
    
    if (selection.baseOffset > 0) {
      final charBefore = text.substring(selection.baseOffset - 1, selection.baseOffset);
      if (charBefore == '@') {
        _showMentionOverlay();
      } else {
        _hideMentionOverlay();
      }
    } else {
      _hideMentionOverlay();
    }
  }

  void _showMentionOverlay() {
    _hideMentionOverlay();
    
    final tasksAsync = ref.read(taskNotifierProvider);
    tasksAsync.whenData((allTasks) {
      final tasksForDate = allTasks.where((t) => 
        t.dueDate.year == widget.date.year &&
        t.dueDate.month == widget.date.month &&
        t.dueDate.day == widget.date.day
      ).toList();

      if (tasksForDate.isEmpty) return;

      _mentionOverlay = OverlayEntry(
        builder: (context) => Positioned(
          width: 250,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 40),
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context).brightness == Brightness.dark 
                  ? const Color(0xFF2D3139) 
                  : Colors.white,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFCDAF56).withOpacity(0.3),
                  ),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: tasksForDate.length,
                  itemBuilder: (context, index) {
                    final task = tasksForDate[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(task.icon ?? Icons.task_alt, size: 18, color: const Color(0xFFCDAF56)),
                      title: Text(task.title, style: const TextStyle(fontSize: 14)),
                      onTap: () {
                        _insertMention(task.title);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      Overlay.of(context).insert(_mentionOverlay!);
    });
  }

  void _insertMention(String taskTitle) {
    final text = _controller.text;
    final selection = _controller.selection;
    final newText = text.replaceRange(selection.baseOffset - 1, selection.baseOffset, '[$taskTitle] ');
    
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(offset: selection.baseOffset + taskTitle.length + 1);
    _hideMentionOverlay();
    _focusNode.requestFocus();
  }

  void _hideMentionOverlay() {
    _mentionOverlay?.remove();
    _mentionOverlay = null;
  }

  Future<void> _save() async {
    final dateKey = DateFormat('yyyy-MM-dd').format(widget.date);
    final content = _controller.text.trim();
    
    // 1. Save to daily reflection provider
    await ref.read(dailyReflectionProvider(dateKey).notifier).save(content);
    
    // 2. ROBUST SYNC: If tasks are mentioned, update those tasks with this reflection
    final tasksAsync = ref.read(taskNotifierProvider);
    tasksAsync.whenData((allTasks) async {
      final notifier = ref.read(taskNotifierProvider.notifier);
      final tasksForDate = allTasks.where((t) => 
        t.dueDate.year == widget.date.year &&
        t.dueDate.month == widget.date.month &&
        t.dueDate.day == widget.date.day
      ).toList();

      for (final task in tasksForDate) {
        // If task title is mentioned in the reflection, sync the reflection to the task
        if (content.contains('[${task.title}]')) {
          final updatedTask = task.copyWith(reflection: content);
          await notifier.updateTask(updatedTask);
        }
      }
    });

    HapticFeedback.mediumImpact();
    setState(() {
      _isEditing = false;
      _initialText = _controller.text;
    });
    if (mounted) AppSnackbar.showSuccess(context, 'Reflection Logged! 📝');
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reflection?'),
        content: const Text('This will permanently remove your log for this day and clear it from mentioned tasks.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final dateKey = DateFormat('yyyy-MM-dd').format(widget.date);
      
      // 1. Clear the daily reflection
      await ref.read(dailyReflectionProvider(dateKey).notifier).save('');
      
      // 2. ROBUST SYNC: Clear reflection from all tasks on this date
      final tasksAsync = ref.read(taskNotifierProvider);
      tasksAsync.whenData((allTasks) async {
        final notifier = ref.read(taskNotifierProvider.notifier);
        final tasksForDate = allTasks.where((t) => 
          t.dueDate.year == widget.date.year &&
          t.dueDate.month == widget.date.month &&
          t.dueDate.day == widget.date.day
        ).toList();

        for (final task in tasksForDate) {
          if (task.reflection != null && task.reflection!.isNotEmpty) {
            // Reset reflection field using direct property access since copyWith doesn't support nulling
            task.reflection = null;
            await notifier.updateTask(task);
          }
        }
      });

      if (mounted) {
        AppSnackbar.showSuccess(context, 'Reflection deleted');
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = DateFormat('MMMM d, yyyy').format(widget.date);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Reflection' : 'Daily Reflection'),
        actions: [
          if (!_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Color(0xFFCDAF56)),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: _delete,
              tooltip: 'Delete',
            ),
          ] else
            TextButton(
              onPressed: _save,
              child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCDAF56))),
            ),
        ],
      ),
      body: isDark ? DarkGradient.wrap(child: _buildBody(isDark, dateStr)) : _buildBody(isDark, dateStr),
    );
  }

  Widget _buildBody(bool isDark, String dateStr) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFFCDAF56)),
              const SizedBox(width: 8),
              Text(
                dateStr,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D3139) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
              ),
            ),
            child: _isEditing
                ? CompositedTransformTarget(
                    link: _layerLink,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(fontSize: 16, height: 1.6),
                      decoration: const InputDecoration(
                        hintText: 'How was your day? Type @ to mention a task...',
                        border: InputBorder.none,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: _controller.text.isEmpty 
                        ? Text(
                            'No reflection written for this day.',
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.6,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        : _buildReflectionText(_controller.text, isDark),
                  ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildReflectionText(String text, bool isDark) {
    // Parse the text to find task mentions in brackets [Task Name]
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\[([^\]]+)\]');
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(text)) {
      // Add text before the match
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: TextStyle(
            fontSize: 16,
            height: 1.6,
            color: isDark ? Colors.white : Colors.black,
          ),
        ));
      }

      // Add the clickable task mention
      final taskName = match.group(1)!;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: GestureDetector(
          onTap: () => _openTaskByName(taskName),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              taskName,
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ));

      lastMatchEnd = match.end;
    }

    // Add remaining text after last match
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: TextStyle(
          fontSize: 16,
          height: 1.6,
          color: isDark ? Colors.white : Colors.black,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  void _openTaskByName(String taskName) async {
    final tasksAsync = ref.read(taskNotifierProvider);
    tasksAsync.whenData((allTasks) {
      // Find tasks for this date
      final tasksForDate = allTasks.where((t) => 
        t.dueDate.year == widget.date.year &&
        t.dueDate.month == widget.date.month &&
        t.dueDate.day == widget.date.day
      ).toList();

      // Find the task by name
      final task = tasksForDate.firstWhere(
        (t) => t.title == taskName,
        orElse: () => tasksForDate.first, // Fallback to first task if not found
      );

      // Open task detail modal
      TaskDetailModal.show(
        context,
        task: task,
        points: task.pointsEarned,
        onTaskUpdated: () {
          ref.invalidate(taskNotifierProvider);
        },
      );
    });
  }
}

/// Completed Tasks Screen - Robust Daily & Monthly Productivity Report
class CompletedTasksScreen extends ConsumerStatefulWidget {
  const CompletedTasksScreen({super.key});

  @override
  ConsumerState<CompletedTasksScreen> createState() => _CompletedTasksScreenState();
}

class _CompletedTasksScreenState extends ConsumerState<CompletedTasksScreen> {
  DateTime _selectedDate = DateTime.now();

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_selectedDate);

  String _formatDateText(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);

    if (selected == today) {
      return 'Today';
    } else if (selected == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  /// Get ALL tasks for a specific date regardless of status
  List<Task> _getAllTasksForDate(List<Task> allTasks, DateTime date) {
    return allTasks.where((task) {
      final taskDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
      final selectedDate = DateTime(date.year, date.month, date.day);
      return taskDate == selectedDate;
    }).toList()
      ..sort((a, b) {
        // Sort: Overdue first, then by time
        if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
        final aTime = a.dueTimeHour ?? 23;
        final bTime = b.dueTimeHour ?? 23;
        return aTime.compareTo(bTime);
      });
  }

  int _calculateStreak(List<Task> allTasks) {
    int streak = 0;
    final today = DateTime.now();
    
    for (int i = 0; i < 365; i++) {
      final checkDate = today.subtract(Duration(days: i));
      final hasCompleted = allTasks.any((task) {
        if (task.status != 'completed' || task.completedAt == null) return false;
        final taskDate = DateTime(
          task.completedAt!.year,
          task.completedAt!.month,
          task.completedAt!.day,
        );
        final checkDateOnly = DateTime(checkDate.year, checkDate.month, checkDate.day);
        return taskDate == checkDateOnly;
      });
      
      if (hasCompleted) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  void _showPointsDetail(BuildContext context, List<Task> tasks, int totalPoints, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2228) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Points Detail',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (totalPoints >= 0 ? const Color(0xFFCDAF56) : Colors.redAccent).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Net: ${totalPoints > 0 ? "+" : ""}$totalPoints',
                    style: TextStyle(
                      color: totalPoints >= 0 ? const Color(0xFFCDAF56) : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final points = task.pointsEarned;
                  if (points == 0 && task.status == 'pending') return const SizedBox.shrink();
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          task.status == 'completed' ? Icons.check_circle_rounded : 
                          task.status == 'not_done' ? Icons.cancel_rounded : Icons.pending_rounded,
                          size: 16,
                          color: task.status == 'completed' ? Colors.green : 
                                 task.status == 'not_done' ? Colors.red : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${points > 0 ? "+" : ""}$points',
                          style: TextStyle(
                            color: points >= 0 ? const Color(0xFFCDAF56) : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tasksAsync = ref.watch(taskNotifierProvider);

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(child: _buildContent(context, isDark, tasksAsync))
          : _buildContent(context, isDark, tasksAsync),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, AsyncValue<List<Task>> tasksAsync) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Productivity Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              AppSnackbar.showInfo(context, 'Exporting report...');
            },
            tooltip: 'Share Report',
          ),
        ],
      ),
      body: SafeArea(
        child: tasksAsync.when(
          data: (allTasks) {
            // ROBUST ANALYSIS: Consider all tasks for that date
            final dayTasks = _getAllTasksForDate(allTasks, _selectedDate);
            
            final totalPlanned = dayTasks.length;
            final dayCompleted = dayTasks.where((t) => t.status == 'completed').length;
            final dayPostponed = dayTasks.where((t) => t.status == 'postponed').length;
            final dayFailed = dayTasks.where((t) => t.status == 'not_done' || (t.isOverdue && t.status == 'pending')).length;
            
            // POINTS CALCULATION: Sum points from all task states
            final totalDayPoints = dayTasks.fold<int>(0, (sum, t) => sum + t.pointsEarned);
            
            // ROBUST ANALYSIS: Performance Score Logic
            // This score represents your efficiency today based on completion AND value (points).
            final completionRate = totalPlanned > 0 ? (dayCompleted / totalPlanned) : 0.0;
            
            // Penalty/Bonus based on points:
            double pointImpact;
            if (totalDayPoints < 0) {
              // Heavy penalty: even if you did half your tasks, negative points mean 
              // you failed high-stakes tasks. We cap the score multiplier significantly.
              pointImpact = 0.5; 
            } else if (totalDayPoints > 0) {
              // Bonus for high point days
              pointImpact = 1.0 + (totalDayPoints / 100).clamp(0.0, 0.5); 
            } else {
              pointImpact = 1.0;
            }

            // The Final Score is (Completion %) x (Point Impact)
            final productivityScore = (completionRate * 100 * pointImpact).toInt().clamp(0, 100);
            
            final currentStreak = _calculateStreak(allTasks);

            return ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                // 1. Heatmap Section (Monthly Overview)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: TaskHeatmap(
                    selectedDate: _selectedDate,
                    onDateSelected: (date) {
                      setState(() {
                        _selectedDate = date;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Date Navigator & Summary Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatDateText(_selectedDate),
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                              ),
                              Text(
                                totalDayPoints < 0 ? 'Focus on recovery. 🛠️' :
                                productivityScore >= 90 ? 'Legendary performance! 👑' :
                                productivityScore >= 75 ? 'Excellent work today! 🚀' : 
                                productivityScore >= 50 ? 'Steady progress. 👍' : 
                                totalPlanned == 0 ? 'Planning day.' : 'Time to pick up the pace. ⚡',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: totalDayPoints < 0 ? Colors.redAccent :
                                             productivityScore >= 75 ? Colors.green : 
                                             productivityScore >= 50 ? const Color(0xFFCDAF56) : 
                                             Colors.grey,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCDAF56).withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFCDAF56), width: 2),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '$productivityScore',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFCDAF56),
                                  ),
                                ),
                                const Text(
                                  'SCORE',
                                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFFCDAF56)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DateNavigatorWidget(
                        selectedDate: _selectedDate,
                        onDateChanged: (newDate) {
                          setState(() {
                            _selectedDate = newDate;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 3. Stats Grid - Robust point system
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: [
                      _StatCard(
                        label: 'Tasks Done',
                        value: dayCompleted.toString(),
                        icon: Icons.check_circle_rounded,
                        isDark: isDark,
                        color: Colors.green,
                      ),
                      GestureDetector(
                        onTap: () => _showPointsDetail(context, dayTasks, totalDayPoints, isDark),
                        child: _StatCard(
                          label: 'Points Earned',
                          value: '${totalDayPoints > 0 ? "+" : ""}$totalDayPoints',
                          icon: Icons.auto_awesome_rounded,
                          isDark: isDark,
                          color: totalDayPoints >= 0 ? const Color(0xFFCDAF56) : Colors.redAccent,
                        ),
                      ),
                      _StatCard(
                        label: 'Current Streak',
                        value: '$currentStreak days',
                        icon: Icons.local_fire_department_rounded,
                        isDark: isDark,
                        color: Colors.orange,
                      ),
                      _StatCard(
                        label: 'Planned Tasks',
                        value: totalPlanned.toString(),
                        icon: Icons.assignment_outlined,
                        isDark: isDark,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 4. Pie Chart Breakdown
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: PieChartWidget(
                    completed: dayCompleted,
                    postponed: dayPostponed,
                    failed: dayFailed,
                  ),
                ),

                const SizedBox(height: 24),

                // 5. Hourly Productivity Chart
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: HourlyProductivityChart(selectedDate: _selectedDate),
                ),

                const SizedBox(height: 24),

                // 6. Completion History - Showing all outcomes
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.history_rounded, size: 20, color: Color(0xFFCDAF56)),
                          const SizedBox(width: 8),
                          Text(
                            'Daily Task History',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (dayTasks.isEmpty)
                        _buildEmptyState(isDark)
                      else
                        ...dayTasks.map((task) => _TaskHistoryCard(
                              task: task,
                              isDark: isDark,
                            )),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 7. Daily Trend Chart
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Card(
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.15),
                    color: isDark ? const Color(0xFF2D3139) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Points Trend (7 Days)',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 200,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: DailyPointsChart(
                              tasks: allTasks.where((t) => t.status == 'completed').toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 8. Daily Reflection
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildReflectionCard(context, isDark),
                ),

                const SizedBox(height: 32),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(Icons.auto_awesome_mosaic_rounded, size: 48, color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.12)),
          const SizedBox(height: 12),
          Text(
            'No task activity for this date.',
            style: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildReflectionCard(BuildContext context, bool isDark) {
    final reflection = ref.watch(dailyReflectionProvider(_dateKey));
    final hasSavedContent = reflection.isNotEmpty;

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.15),
      color: isDark ? const Color(0xFF2D3139) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReflectionDetailScreen(
                date: _selectedDate,
                isEditing: !hasSavedContent,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCDAF56).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          hasSavedContent ? Icons.description_rounded : Icons.edit_note_rounded,
                          color: const Color(0xFFCDAF56),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Daily Reflection',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 18,
                            ),
                      ),
                    ],
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ],
              ),
              if (hasSavedContent) ...[
                const SizedBox(height: 16),
                Text(
                  reflection,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Text(
                  'How was today? Log your thoughts and link your tasks...',
                  style: TextStyle(
                    color: isDark ? Colors.white24 : Colors.black26,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDark;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 20,
                ),
          ),
        ],
      ),
    );
  }
}

/// Task History Card - Shows Done, Not Done, or Postponed status
class _TaskHistoryCard extends ConsumerWidget {
  final Task task;
  final bool isDark;

  const _TaskHistoryCard({required this.task, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine status styling
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    if (task.status == 'completed') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_rounded;
      statusText = 'Done at ${task.completedAt != null ? DateFormat('h:mm a').format(task.completedAt!) : "completed"}';
    } else if (task.status == 'postponed') {
      statusColor = Colors.orange;
      statusIcon = Icons.schedule_rounded;
      statusText = 'Postponed to ${task.postponedTo != null ? DateFormat('MMM d').format(task.postponedTo!) : "later"}';
    } else if (task.status == 'not_done') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel_rounded;
      statusText = 'Marked as Not Done';
    } else if (task.isOverdue) {
      statusColor = Colors.redAccent;
      statusIcon = Icons.warning_rounded;
      statusText = 'Overdue';
    } else {
      statusColor = Colors.blueGrey;
      statusIcon = Icons.pending_rounded;
      statusText = 'Pending';
    }

    return GestureDetector(
      onTap: () {
        TaskDetailModal.show(context, task: task, points: task.pointsEarned, onTaskUpdated: () => ref.invalidate(taskNotifierProvider));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                      decoration: (task.status == 'completed' || task.status == 'not_done') ? TextDecoration.lineThrough : null,
                      decorationColor: Colors.grey,
                    ),
                  ),
                  Text(
                    statusText,
                    style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400], fontSize: 11),
                  ),
                ],
              ),
            ),
            // Show points (positive or negative)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (task.pointsEarned >= 0 ? const Color(0xFFCDAF56) : Colors.redAccent).withOpacity(0.1), 
                borderRadius: BorderRadius.circular(8)
              ),
              child: Text(
                '${task.pointsEarned >= 0 ? "+" : ""}${task.pointsEarned}', 
                style: TextStyle(
                  color: task.pointsEarned >= 0 ? const Color(0xFFCDAF56) : Colors.redAccent, 
                  fontWeight: FontWeight.bold, 
                  fontSize: 12
                )
              ),
            ),
          ],
        ),
      ),
    );
  }
}
