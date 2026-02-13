import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../../../data/models/task_template.dart';
import '../../../../data/models/category.dart';

/// Template Report Screen
/// 
/// Displays detailed usage statistics and timeline for a template.
class TemplateReportScreen extends ConsumerWidget {
  final TaskTemplate template;
  final Category? category;

  const TemplateReportScreen({
    super.key,
    required this.template,
    this.category,
  });

  static const Color _accentColor = Color(0xFFCDAF56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(child: _buildContent(context, isDark))
          : _buildContent(context, isDark),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    final categoryColor = category?.color ?? _accentColor;
    final templateIcon = template.icon ?? Icons.task_alt_rounded;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Template Report',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Template Header Card
            _buildHeaderCard(context, isDark, categoryColor, templateIcon),
            
            const SizedBox(height: 20),
            
            // Stats Grid
            _buildStatsGrid(context, isDark),
            
            const SizedBox(height: 24),
            
            // Usage Timeline
            _buildUsageTimeline(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, bool isDark, Color categoryColor, IconData templateIcon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            categoryColor.withOpacity(0.15),
            categoryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: categoryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(templateIcon, size: 32, color: categoryColor),
              ),
              const SizedBox(width: 16),
              
              // Title & Category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    if (category != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(category!.icon, size: 14, color: categoryColor),
                          const SizedBox(width: 6),
                          Text(
                            category!.name,
                            style: TextStyle(
                              fontSize: 13,
                              color: categoryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              // Priority Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _getPriorityColor(template.priority).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  template.priority.toUpperCase(),
                  style: TextStyle(
                    color: _getPriorityColor(template.priority),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          
          if (template.description != null && template.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                template.description!,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, bool isDark) {
    final createdFormat = DateFormat('MMM d, yyyy');
    final lastUsedFormat = DateFormat('MMM d, yyyy • h:mm a');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STATISTICS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white38 : Colors.black38,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.calendar_today_rounded,
                label: 'Created',
                value: createdFormat.format(template.createdAt),
                color: const Color(0xFF64B5F6),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.play_circle_rounded,
                label: 'Total Uses',
                value: '${template.usageCount}',
                color: _accentColor,
                isDark: isDark,
                isHighlighted: true,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 10),
        
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.schedule_rounded,
                label: 'Last Used',
                value: template.lastUsedAt != null
                    ? lastUsedFormat.format(template.lastUsedAt!)
                    : 'Never',
                color: const Color(0xFF81C784),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.trending_up_rounded,
                label: 'Avg per Month',
                value: _calculateAvgPerMonth(),
                color: const Color(0xFFBA68C8),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _calculateAvgPerMonth() {
    if (template.usageCount == 0) return '0';
    
    final now = DateTime.now();
    final daysSinceCreated = now.difference(template.createdAt).inDays;
    if (daysSinceCreated < 30) {
      return '${template.usageCount}';
    }
    
    final months = daysSinceCreated / 30;
    final avg = template.usageCount / months;
    return avg.toStringAsFixed(1);
  }

  Widget _buildUsageTimeline(BuildContext context, bool isDark) {
    final usageHistory = template.usageHistory ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'USAGE TIMELINE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white38 : Colors.black38,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            if (usageHistory.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${usageHistory.length} entries',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _accentColor,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (usageHistory.isEmpty)
          _buildEmptyTimeline(isDark)
        else
          _buildTimelineList(context, isDark, usageHistory),
      ],
    );
  }

  Widget _buildEmptyTimeline(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.timeline_rounded,
              size: 32,
              color: _accentColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Usage History Yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Use this template to create tasks\nand see your usage history here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.black38,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineList(BuildContext context, bool isDark, List<DateTime> usageHistory) {
    // Sort by most recent first
    final sortedHistory = List<DateTime>.from(usageHistory)
      ..sort((a, b) => b.compareTo(a));
    
    // Group by date
    final Map<String, List<DateTime>> groupedByDate = {};
    final dateFormat = DateFormat('yyyy-MM-dd');
    
    for (final date in sortedHistory) {
      final key = dateFormat.format(date);
      groupedByDate.putIfAbsent(key, () => []).add(date);
    }
    
    final groupKeys = groupedByDate.keys.toList();
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (int i = 0; i < groupKeys.length; i++)
            _TimelineGroup(
              date: DateTime.parse(groupKeys[i]),
              usages: groupedByDate[groupKeys[i]]!,
              isFirst: i == 0,
              isLast: i == groupKeys.length - 1,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFFF5252);
      case 'medium':
        return const Color(0xFFFFA726);
      case 'low':
        return const Color(0xFF66BB6A);
      default:
        return Colors.grey;
    }
  }
}

/// Stat Card Widget
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  final bool isHighlighted;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighlighted
            ? color.withOpacity(0.12)
            : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08)),
        borderRadius: BorderRadius.circular(14),
        border: isHighlighted
            ? Border.all(color: color.withOpacity(0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlighted ? 24 : 14,
              fontWeight: FontWeight.bold,
              color: isHighlighted ? color : (isDark ? Colors.white : Colors.black87),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Timeline Group Widget
class _TimelineGroup extends StatelessWidget {
  final DateTime date;
  final List<DateTime> usages;
  final bool isFirst;
  final bool isLast;
  final bool isDark;

  const _TimelineGroup({
    required this.date,
    required this.usages,
    required this.isFirst,
    required this.isLast,
    required this.isDark,
  });

  static const Color _accentColor = Color(0xFFCDAF56);

  String _getDateLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');
    
    return Container(
      padding: EdgeInsets.only(
        top: isFirst ? 16 : 8,
        bottom: isLast ? 16 : 8,
        left: 16,
        right: 16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Line & Dot
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _accentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _accentColor.withOpacity(0.3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40 + (usages.length - 1) * 24.0,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _accentColor.withOpacity(0.5),
                          _accentColor.withOpacity(0.1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Label
                Row(
                  children: [
                    Text(
                      _getDateLabel(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _accentColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${usages.length}x',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 6),
                
                // Time entries
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: usages.map((usage) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeFormat.format(usage),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
