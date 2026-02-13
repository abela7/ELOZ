import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/habit.dart';
import '../../data/models/temptation_log.dart';
import '../providers/habit_providers.dart';
import '../providers/temptation_log_providers.dart';
import 'log_temptation_modal.dart';

/// Beautiful card showing temptation history for a quit habit
class TemptationHistoryCard extends ConsumerWidget {
  final String habitId;
  final String habitTitle;
  final VoidCallback? onLogAdded;

  const TemptationHistoryCard({
    super.key,
    required this.habitId,
    required this.habitTitle,
    this.onLogAdded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final habitAsync = ref.watch(habitByIdProvider(habitId));
    final Habit? habit = habitAsync.maybeWhen(data: (habit) => habit, orElse: () => null);
    final habitColor = habit?.color ?? const Color(0xFF9C27B0);
    final logsAsync = ref.watch(habitTemptationLogsProvider(habitId));
    final todayCount = ref.watch(todayTemptationCountProvider(habitId));
    final totalCount = ref.watch(totalTemptationCountProvider(habitId));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(context, isDark, todayCount, totalCount, ref, habit, habitColor),
          
          // Content
          logsAsync.when(
            data: (logs) => logs.isEmpty 
                ? _buildEmptyState(context, isDark, ref, habit, habitColor)
                : _buildLogsList(context, isDark, logs, ref),
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Error loading temptation history',
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, 
    bool isDark, 
    AsyncValue<int> todayCount,
    AsyncValue<int> totalCount,
    WidgetRef ref,
    Habit? habit,
    Color habitColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            habitColor.withOpacity(0.1),
            habitColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: habitColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.psychology_rounded,
              color: habitColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Temptation Tracker',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    todayCount.when(
                      data: (count) => _buildStatChip('Today: $count', isDark, habitColor),
                      loading: () => _buildStatChip('...', isDark, habitColor),
                      error: (_, __) => _buildStatChip('-', isDark, habitColor),
                    ),
                    const SizedBox(width: 8),
                    totalCount.when(
                      data: (count) => _buildStatChip('Total: $count', isDark, habitColor),
                      loading: () => _buildStatChip('...', isDark, habitColor),
                      error: (_, __) => _buildStatChip('-', isDark, habitColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Add button
          IconButton(
            onPressed: () {
              if (habit == null) return;
              LogTemptationModal.show(
                context,
                habit: habit,
                habitId: habitId,
                habitTitle: habitTitle,
                onLogged: () {
                  ref.invalidate(habitTemptationLogsProvider(habitId));
                  onLogAdded?.call();
                },
              );
            },
            style: IconButton.styleFrom(
              backgroundColor: habitColor,
              padding: const EdgeInsets.all(10),
            ),
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String text, bool isDark, Color habitColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: habitColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : habitColor,
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isDark,
    WidgetRef ref,
    Habit? habit,
    Color habitColor,
  ) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.sentiment_satisfied_alt_rounded,
            size: 48,
            color: const Color(0xFF4CAF50).withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'No temptations logged yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'You\'re doing great! Keep it up! 💪',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () {
              if (habit == null) return;
              LogTemptationModal.show(
                context,
                habit: habit,
                habitId: habitId,
                habitTitle: habitTitle,
                onLogged: () {
                  ref.invalidate(habitTemptationLogsProvider(habitId));
                  onLogAdded?.call();
                },
              );
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Log a temptation'),
            style: TextButton.styleFrom(
              foregroundColor: habitColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList(
    BuildContext context, 
    bool isDark, 
    List<TemptationLog> logs,
    WidgetRef ref,
  ) {
    // Group logs by date
    final groupedLogs = <String, List<TemptationLog>>{};
    for (final log in logs) {
      final dateKey = log.formattedDate;
      groupedLogs.putIfAbsent(dateKey, () => []).add(log);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: groupedLogs.entries.take(5).map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
                child: Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              // Logs for this date
              ...entry.value.map((log) => _buildLogItem(context, isDark, log, ref)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLogItem(
    BuildContext context, 
    bool isDark, 
    TemptationLog log,
    WidgetRef ref,
  ) {
    return Dismissible(
      key: Key(log.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        ref.read(temptationLogNotifierProvider.notifier).deleteLog(log.id);
        ref.invalidate(habitTemptationLogsProvider(habitId));
        ref.invalidate(todayTemptationCountProvider(habitId));
        ref.invalidate(totalTemptationCountProvider(habitId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Temptation log deleted'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark 
              ? Colors.white.withOpacity(0.05) 
              : log.intensityColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: log.intensityColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Intensity indicator
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: log.intensityColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                log.intensityIcon,
                color: log.intensityColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (log.reasonText != null) ...[
                        if (log.icon != null)
                          Icon(log.icon, color: log.color, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            log.reasonText!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else
                        Text(
                          'Temptation logged',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        log.formattedTime,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: log.intensityColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          log.intensityName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: log.intensityColor,
                          ),
                        ),
                      ),
                      if (log.count > 1) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9C27B0).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '×${log.count}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF9C27B0),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (log.customNote != null && log.customNote!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      log.customNote!,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white38 : Colors.grey[500],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
