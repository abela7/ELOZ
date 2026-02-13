import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../../data/models/simple_reminder.dart';
import '../providers/reminder_providers.dart';
import '../widgets/add_reminder_sheet.dart';
import 'pending_reminders_screen.dart';

/// Reminders Screen - Dedicated screen for managing simple reminders
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  DateTime _selectedDate = DateTime.now();
  Timer? _refreshTimer;
  String _filterMode = 'all'; // 'all', 'pending', 'done'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Refresh reminders every minute to update countdown/count-up text
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remindersAsync = ref.watch(reminderNotifierProvider);
    final selectedDate = _selectedDate;

    // Get reminders based on filter + search query
    final allReminders = remindersAsync.valueOrNull ?? [];
    List<SimpleReminder> filteredReminders;
    
    switch (_filterMode) {
      case 'pending':
        filteredReminders = allReminders.where((r) => r.isPending).toList();
        break;
      case 'done':
        filteredReminders = allReminders.where((r) => r.isDone).toList();
        break;
      default:
        filteredReminders = allReminders;
    }

    // Apply search query
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      filteredReminders = filteredReminders.where((reminder) {
        final title = reminder.title.toLowerCase();
        final desc = (reminder.description ?? '').toLowerCase();
        return title.contains(query) || desc.contains(query);
      }).toList();
    }

    // Get reminders for selected date
    final selectedDateReminders = filteredReminders.where((reminder) {
      final reminderDate = DateTime(
        reminder.scheduledAt.year,
        reminder.scheduledAt.month,
        reminder.scheduledAt.day,
      );
      final targetDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      return reminderDate == targetDate;
    }).toList();
    
    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF10141C) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        title: Row(
          children: [
            Icon(
              Icons.notifications_active_rounded,
              color: const Color(0xFFCDAF56),
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              'Reminders',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          // Stats badge
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PendingRemindersScreen()),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFCDAF56).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${ref.watch(pendingRemindersCountProvider)}',
                    style: const TextStyle(
                      color: Color(0xFFCDAF56),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'pending',
                    style: TextStyle(
                      color: Color(0xFFCDAF56),
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            color: isDark ? const Color(0xFF1A1D24) : Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search reminders...',
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white54 : Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: Icon(Icons.clear_rounded, color: isDark ? Colors.white54 : Colors.grey),
                      )
                    : null,
                filled: true,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Filter Chips with Add Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D24) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  isSelected: _filterMode == 'all',
                  isDark: isDark,
                  onTap: () => setState(() => _filterMode = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Pending',
                  isSelected: _filterMode == 'pending',
                  isDark: isDark,
                  onTap: () => setState(() => _filterMode = 'pending'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Done',
                  isSelected: _filterMode == 'done',
                  isDark: isDark,
                  onTap: () => setState(() => _filterMode = 'done'),
                ),
                const Spacer(),
                // Add Button
                GestureDetector(
                  onTap: () => _showAddReminderSheet(context, isDark),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCDAF56),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Date Navigator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D24) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                ),
              ),
            ),
            child: _ReminderDateNavigator(
              selectedDate: _selectedDate,
              onDateChanged: (date) => setState(() => _selectedDate = date),
              isDark: isDark,
            ),
          ),

          // Reminders List
          Expanded(
            child: remindersAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFFCDAF56)),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: Colors.red[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading reminders',
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    ),
                  ],
                ),
              ),
              data: (_) {
                if (selectedDateReminders.isEmpty) {
                  return Center(
                    child: _buildEmptyState(
                      context,
                      isDark,
                      'No reminders${isToday ? ' for today' : ''}',
                    ),
                  );
                }

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(
                          title: DateFormat('EEEE, MMM d').format(selectedDate),
                          count: selectedDateReminders.length,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        ...selectedDateReminders.map((reminder) => Dismissible(
                              key: ValueKey('reminder_${reminder.id}'),
                              background: _SwipeActionBackground(
                                icon: Icons.check_circle_rounded,
                                label: reminder.isDone ? 'Undo' : 'Done',
                                color: const Color(0xFF4CAF50),
                                isDark: isDark,
                                alignRight: false,
                              ),
                              secondaryBackground: _SwipeActionBackground(
                                icon: Icons.delete_rounded,
                                label: 'Delete',
                                color: const Color(0xFFFF6B6B),
                                isDark: isDark,
                                alignRight: true,
                              ),
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.startToEnd) {
                                  if (reminder.isDone) {
                                    await ref.read(reminderNotifierProvider.notifier).markReminderPending(reminder.id);
                                  } else {
                                    await ref.read(reminderNotifierProvider.notifier).markReminderDone(reminder.id);
                                  }
                                  return false;
                                }
                                if (direction == DismissDirection.endToStart) {
                                  await ref.read(reminderNotifierProvider.notifier).deleteReminder(reminder.id);
                                  return true;
                                }
                                return false;
                              },
                              child: _ReminderCard(
                                reminder: reminder,
                                isDark: isDark,
                                onTap: () => _showReminderActions(context, isDark, reminder),
                              ),
                            )),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, String message) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 48,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDark ? Colors.white38 : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first reminder',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white24 : Colors.grey[400],
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showAddReminderSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => AddReminderSheet(
        isDark: isDark,
        initialDate: _selectedDate,
        onReminderAdded: () {
          // Refresh reminders
          ref.invalidate(reminderNotifierProvider);
        },
      ),
    );
  }

  void _showEditReminderSheet(BuildContext context, bool isDark, SimpleReminder reminder) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => AddReminderSheet(
        isDark: isDark,
        initialDate: reminder.scheduledAt,
        existingReminder: reminder,
        onReminderAdded: () {
          ref.invalidate(reminderNotifierProvider);
        },
      ),
    );
  }

  void _showReminderActions(BuildContext context, bool isDark, SimpleReminder reminder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    reminder.isDone ? Icons.check_circle_rounded : Icons.notifications_active_rounded,
                    color: reminder.isDone ? const Color(0xFF4CAF50) : const Color(0xFFCDAF56),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      reminder.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                reminder.isPinned ? Icons.star_rounded : Icons.star_outline_rounded,
                color: const Color(0xFFCDAF56),
              ),
              title: Text(
                reminder.isPinned ? 'Unpin' : 'Pin to Top',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(reminderNotifierProvider.notifier).togglePin(reminder.id);
              },
            ),
            ListTile(
              leading: Icon(
                reminder.isDone ? Icons.undo_rounded : Icons.check_circle_rounded,
                color: reminder.isDone ? const Color(0xFFCDAF56) : const Color(0xFF4CAF50),
              ),
              title: Text(
                reminder.isDone ? 'Undo Done' : 'Mark as Done',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                if (reminder.isDone) {
                  await ref.read(reminderNotifierProvider.notifier).markReminderPending(reminder.id);
                } else {
                  await ref.read(reminderNotifierProvider.notifier).markReminderDone(reminder.id);
                }
              },
            ),
            ListTile(
              leading: Icon(
                Icons.edit_rounded,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              title: Text(
                'Edit Reminder',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showEditReminderSheet(context, isDark, reminder);
              },
            ),
            if (!reminder.isDone)
              ListTile(
                leading: const Icon(
                  Icons.timer_rounded,
                  color: Color(0xFFCDAF56),
                ),
                title: Text(
                  'Start Count Up',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(reminderNotifierProvider.notifier).startCountup(reminder.id);
                },
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_rounded,
                color: Color(0xFFFF6B6B),
              ),
              title: const Text(
                'Delete',
                style: TextStyle(color: Color(0xFFFF6B6B)),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(reminderNotifierProvider.notifier).deleteReminder(reminder.id);
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

}

/// Section Header Widget
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool isDark;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFCDAF56).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Color(0xFFCDAF56),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

/// Filter Chip Widget
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFCDAF56)
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFCDAF56)
                : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.black
                : (isDark ? Colors.white70 : Colors.black54),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// Swipe background for reminder actions
class _SwipeActionBackground extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final bool alignRight;

  const _SwipeActionBackground({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.alignRight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.15),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignRight) ...[
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(
            icon,
            color: color,
          ),
          if (!alignRight) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mini Date Navigator for Reminders
class _ReminderDateNavigator extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final bool isDark;

  const _ReminderDateNavigator({
    required this.selectedDate,
    required this.onDateChanged,
    required this.isDark,
  });

  String _formatDateText(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);

    if (selected == today) {
      return 'Today';
    } else if (selected == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (selected == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else {
      return DateFormat('EEE, MMM d').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final isToday = selected == today;

    return Row(
      children: [
        // Previous Day
        IconButton(
          onPressed: () => onDateChanged(selectedDate.subtract(const Duration(days: 1))),
          icon: Icon(
            Icons.chevron_left_rounded,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        
        // Date Text
        Expanded(
          child: GestureDetector(
            onTap: () => _showDatePicker(context),
            child: Center(
              child: Text(
                _formatDateText(selectedDate),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
              ),
            ),
          ),
        ),
        
        // Next Day
        IconButton(
          onPressed: () => onDateChanged(selectedDate.add(const Duration(days: 1))),
          icon: Icon(
            Icons.chevron_right_rounded,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        
        // Today Button (if not on today)
        if (!isToday) ...[
          const SizedBox(width: 4),
          TextButton(
            onPressed: () => onDateChanged(DateTime.now()),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              backgroundColor: const Color(0xFFCDAF56).withOpacity(0.15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Today',
              style: TextStyle(
                color: Color(0xFFCDAF56),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFFCDAF56),
                    onPrimary: Colors.black,
                    surface: Color(0xFF2D3139),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFFCDAF56),
                    onPrimary: Colors.white,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onDateChanged(picked);
    }
  }
}

/// Reminder Card Widget
class _ReminderCard extends StatelessWidget {
  final SimpleReminder reminder;
  final bool isDark;
  final VoidCallback onTap;

  const _ReminderCard({
    required this.reminder,
    required this.isDark,
    required this.onTap,
  });

  Color get _statusColor {
    if (reminder.isDone) return const Color(0xFF4CAF50);
    if (reminder.isOverdue) return const Color(0xFFFF6B6B);
    return const Color(0xFFCDAF56);
  }

  @override
  Widget build(BuildContext context) {
    final color = reminder.color ?? _statusColor;
    final icon = reminder.icon ?? Icons.notifications_active_rounded;
    final hasTimer = reminder.timerMode != ReminderTimerMode.none;
    final timerText = hasTimer ? reminder.getTimerText() : '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showLongPressOptions(context, isDark),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: reminder.isDone
                ? const Color(0xFF4CAF50).withOpacity(0.3)
                : color.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: (reminder.isDone ? const Color(0xFF4CAF50) : color).withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              reminder.isDone ? Icons.check_rounded : icon,
              color: reminder.isDone ? const Color(0xFF4CAF50) : color,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        reminder.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: reminder.isDone
                                  ? (isDark ? Colors.white54 : Colors.grey)
                                  : (isDark ? Colors.white : Colors.black87),
                              decoration: reminder.isDone ? TextDecoration.lineThrough : null,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (reminder.isPinned)
                      Padding(
                        padding: const EdgeInsets.only(left: 6, top: 2),
                        child: Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: const Color(0xFFCDAF56),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Time and Timer
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: isDark ? Colors.white54 : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('h:mm a').format(reminder.scheduledAt),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isDark ? Colors.white54 : Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (hasTimer && timerText.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          timerText,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: _statusColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                        ),
                      ),
                    if (reminder.isDone)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Done',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF4CAF50),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                        ),
                      ),
                  ],
                ),
                
                // Description (if any)
                if (reminder.description != null && reminder.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    reminder.description!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white38 : Colors.grey[600],
                          fontSize: 13,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(width: 4),
          Icon(
            Icons.more_horiz_rounded,
            color: isDark ? Colors.white38 : Colors.grey,
          ),
        ],
      ),
        ),
      ),
    );
  }

  void _showLongPressOptions(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListTile(
                leading: Icon(
                  Icons.add_rounded,
                  color: const Color(0xFFCDAF56),
                  size: 24,
                ),
                title: Text(
                  'Create New Reminder',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  'Add a new reminder',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  // Find the RemindersScreen state and call _showAddReminderSheet
                  final state = context.findAncestorStateOfType<_RemindersScreenState>();
                  if (state != null) {
                    state._showAddReminderSheet(context, isDark);
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

