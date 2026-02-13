import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/simple_reminder.dart';
import '../providers/reminder_providers.dart';
import '../widgets/add_reminder_sheet.dart';

/// Pending Reminders Screen - Shows all pending/overdue reminders across all dates
class PendingRemindersScreen extends ConsumerStatefulWidget {
  const PendingRemindersScreen({super.key});

  @override
  ConsumerState<PendingRemindersScreen> createState() => _PendingRemindersScreenState();
}

class _PendingRemindersScreenState extends ConsumerState<PendingRemindersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remindersAsync = ref.watch(reminderNotifierProvider);

    // Get all pending reminders
    final allReminders = remindersAsync.valueOrNull ?? [];
    List<SimpleReminder> pendingReminders = allReminders.where((r) => r.isPending).toList();

    // Apply search query
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      pendingReminders = pendingReminders.where((reminder) {
        final title = reminder.title.toLowerCase();
        final desc = (reminder.description ?? '').toLowerCase();
        return title.contains(query) || desc.contains(query);
      }).toList();
    }

    // Sort by date (oldest first to see what was missed)
    pendingReminders.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

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
              Icons.pending_actions_rounded,
              color: const Color(0xFFCDAF56),
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              'Pending Reminders',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            color: isDark ? const Color(0xFF1A1D24) : Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search pending...',
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

          // List
          Expanded(
            child: remindersAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFFCDAF56)),
              ),
              error: (e, _) => Center(
                child: Text('Error loading reminders', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
              ),
              data: (_) {
                if (pendingReminders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 64,
                          color: isDark ? Colors.white12 : Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'All caught up!',
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.grey,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No pending reminders found',
                          style: TextStyle(
                            color: isDark ? Colors.white24 : Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Group by date for better organization
                final Map<String, List<SimpleReminder>> grouped = {};
                for (final r in pendingReminders) {
                  final dateKey = DateFormat('yyyy-MM-dd').format(r.scheduledAt);
                  if (!grouped.containsKey(dateKey)) grouped[dateKey] = [];
                  grouped[dateKey]!.add(r);
                }

                final sortedDates = grouped.keys.toList()..sort();

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: sortedDates.length,
                  itemBuilder: (context, index) {
                    final dateKey = sortedDates[index];
                    final dateReminders = grouped[dateKey]!;
                    final date = DateTime.parse(dateKey);
                    final isOverdue = date.isBefore(DateTime.now().subtract(const Duration(days: 1)));

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12, top: 8),
                          child: Row(
                            children: [
                              Text(
                                _formatDateHeader(date),
                                style: TextStyle(
                                  color: isOverdue ? const Color(0xFFFF6B6B) : (isDark ? Colors.white70 : Colors.black54),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isOverdue ? const Color(0xFFFF6B6B) : const Color(0xFFCDAF56)).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${dateReminders.length}',
                                  style: TextStyle(
                                    color: isOverdue ? const Color(0xFFFF6B6B) : const Color(0xFFCDAF56),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...dateReminders.map((reminder) => _buildDismissibleReminder(context, reminder, isDark)),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);

    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    if (d.isBefore(today)) {
      final diff = today.difference(d).inDays;
      if (diff < 7) return '${DateFormat('EEEE').format(date)} ($diff days ago)';
      return DateFormat('MMM d, yyyy').format(date);
    }
    return DateFormat('MMM d, yyyy').format(date);
  }

  Widget _buildDismissibleReminder(BuildContext context, SimpleReminder reminder, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey('pending_reminder_${reminder.id}'),
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.2),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50)),
              SizedBox(width: 8),
              Text('Done', style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B6B).withOpacity(0.2),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Delete', style: TextStyle(color: Color(0xFFFF6B6B), fontWeight: FontWeight.w700)),
              SizedBox(width: 8),
              Icon(Icons.delete_rounded, color: Color(0xFFFF6B6B)),
            ],
          ),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            await ref.read(reminderNotifierProvider.notifier).markReminderDone(reminder.id);
            return true;
          }
          if (direction == DismissDirection.endToStart) {
            await ref.read(reminderNotifierProvider.notifier).deleteReminder(reminder.id);
            return true;
          }
          return false;
        },
        child: _PendingReminderCard(
          reminder: reminder,
          isDark: isDark,
          onTap: () => _showEditReminderSheet(context, isDark, reminder),
        ),
      ),
    );
  }

  void _showEditReminderSheet(BuildContext context, bool isDark, SimpleReminder reminder) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
}

class _PendingReminderCard extends StatelessWidget {
  final SimpleReminder reminder;
  final bool isDark;
  final VoidCallback onTap;

  const _PendingReminderCard({
    required this.reminder,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = reminder.isOverdue;
    final color = isOverdue ? const Color(0xFFFF6B6B) : const Color(0xFFCDAF56);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withOpacity(0.3),
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
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isOverdue ? Icons.priority_high_rounded : Icons.notifications_active_rounded,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: isDark ? Colors.white38 : Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('h:mm a').format(reminder.scheduledAt),
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isOverdue) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Overdue',
                          style: TextStyle(
                            color: const Color(0xFFFF6B6B),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
          ],
        ),
      ),
    );
  }
}
