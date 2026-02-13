import 'package:flutter/material.dart';

/// Home Screen - Dark theme version with purple and gold
class HomeScreenDark extends StatelessWidget {
  const HomeScreenDark({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
              ? [
                  const Color(0xFF301934), // Dark purple base
                  const Color(0xFF1F0F2B), // Darker purple
                ]
              : [
                  const Color(0xFFF9F7F2),
                  const Color(0xFFEDE9E0),
                ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 100), // Space for bottom nav
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hey Abela! 👋',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: isDark 
                          ? const Color(0xFFFFFFFF)
                          : const Color(0xFF1E1E1E),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ready to manage your day?',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        color: isDark
                          ? const Color(0xFFBDBDBD)
                          : const Color(0xFF6E6E6E),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Today Overview Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                      ? const Color(0xFF3D2249).withOpacity(0.9) // Purple card
                      : const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border: isDark
                      ? Border.all(
                          color: const Color(0xFF5A4A6A).withOpacity(0.3),
                          width: 1,
                        )
                      : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today Overview',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: isDark
                            ? const Color(0xFFFFFFFF)
                            : const Color(0xFF1E1E1E),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(
                            icon: Icons.task_alt_rounded,
                            label: 'Tasks',
                            value: '5',
                            isDark: isDark,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: isDark
                              ? const Color(0xFF5A4A6A)
                              : const Color(0xFFEDE9E0),
                          ),
                          _StatItem(
                            icon: Icons.auto_awesome_rounded,
                            label: 'Habits',
                            value: '3/5',
                            isDark: isDark,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: isDark
                              ? const Color(0xFF5A4A6A)
                              : const Color(0xFFEDE9E0),
                          ),
                          _StatItem(
                            icon: Icons.mood_rounded,
                            label: 'Mood',
                            value: '😊',
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Quick Actions Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: isDark
                          ? const Color(0xFFFFFFFF)
                          : const Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Row 1
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionButton(
                            icon: Icons.add_task_rounded,
                            label: 'Add Task',
                            isDark: isDark,
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionButton(
                            icon: Icons.check_circle_outline_rounded,
                            label: 'Log Habit',
                            isDark: isDark,
                            onTap: () {},
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Row 2
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionButton(
                            icon: Icons.bar_chart_rounded,
                            label: 'View Stats',
                            isDark: isDark,
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionButton(
                            icon: Icons.more_horiz_rounded,
                            label: 'More',
                            isDark: isDark,
                            onTap: () {},
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFFCDAF56), // Gold accent always
          size: 28,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark
              ? const Color(0xFFFFFFFF)
              : const Color(0xFF1E1E1E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 12,
            color: isDark
              ? const Color(0xFFBDBDBD)
              : const Color(0xFF6E6E6E),
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
          ? const Color(0xFF3D2249).withOpacity(0.7) // Semi-transparent purple
          : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFCDAF56), // Gold border
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: const Color(0xFFCDAF56).withOpacity(0.2),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: const Color(0xFFCDAF56), // Gold icon
                  size: 24,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark
                        ? const Color(0xFFFFFFFF)
                        : const Color(0xFF1E1E1E),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

