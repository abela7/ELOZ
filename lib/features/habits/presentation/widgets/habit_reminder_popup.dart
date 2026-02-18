import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/color_schemes.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/reminder_manager.dart';
import '../../../../core/models/notification_settings.dart';
import '../../../../routing/app_router.dart';
import '../../data/models/habit.dart';
import '../../data/models/habit_notification_settings.dart';
import '../../data/repositories/habit_repository.dart';
import '../../providers/habit_notification_settings_provider.dart';
import '../providers/habit_providers.dart';
import 'skip_reason_dialog.dart';

/// Modern Habit Reminder Popup - Clean, minimal design
/// 
/// Features:
/// - Elegant glassmorphism design
/// - Quick action buttons
/// - Snooze with habit preference support
/// - Streak and progress display
/// - Smooth animations
class HabitReminderPopup extends ConsumerStatefulWidget {
  final Habit habit;
  final VoidCallback? onDismiss;

  const HabitReminderPopup({
    super.key,
    required this.habit,
    this.onDismiss,
  });

  /// Show the reminder popup as an overlay
  static void show(BuildContext context, Habit habit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      barrierColor: Colors.black54,
      builder: (context) => HabitReminderPopup(habit: habit),
    );
  }

  @override
  ConsumerState<HabitReminderPopup> createState() => _HabitReminderPopupState();
}

class _HabitReminderPopupState extends ConsumerState<HabitReminderPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // App theme colors (gold accent)
  static const _goldPrimary = Color(0xFFCDAF56);
  static const _goldLight = Color(0xFFE8D48A);
  static const _goldDark = Color(0xFFB89B3E);

  NotificationSettings _mapHabitSettings(HabitNotificationSettings h) {
    return NotificationSettings(
      notificationsEnabled: h.notificationsEnabled,
      soundEnabled: h.soundEnabled,
      vibrationEnabled: h.vibrationEnabled,
      ledEnabled: h.ledEnabled,
      taskRemindersEnabled: h.habitRemindersEnabled,
      urgentRemindersEnabled: h.urgentRemindersEnabled,
      silentRemindersEnabled: h.silentRemindersEnabled,
      defaultSound: h.defaultSound,
      taskRemindersSound: h.habitRemindersSound,
      urgentRemindersSound: h.urgentRemindersSound,
      defaultVibrationPattern: h.defaultVibrationPattern,
      defaultChannel: h.defaultChannel,
      notificationAudioStream: h.notificationAudioStream,
      alwaysUseAlarmForSpecialTasks: h.alwaysUseAlarmForSpecialHabits,
      specialTaskSound: h.specialHabitSound,
      specialTaskVibrationPattern: h.specialHabitVibrationPattern,
      specialTaskAlarmMode: h.specialHabitAlarmMode,
      allowUrgentDuringQuietHours: h.allowSpecialDuringQuietHours,
      quietHoursEnabled: h.quietHoursEnabled,
      quietHoursStart: h.quietHoursStart,
      quietHoursEnd: h.quietHoursEnd,
      quietHoursDays: h.quietHoursDays,
      showOnLockScreen: h.showOnLockScreen,
      wakeScreen: h.wakeScreen,
      persistentNotifications: h.persistentNotifications,
      groupNotifications: h.groupNotifications,
      notificationTimeout: h.notificationTimeout,
      defaultSnoozeDuration: h.defaultSnoozeDuration,
      snoozeOptions: h.snoozeOptions,
      maxSnoozeCount: h.maxSnoozeCount,
      smartSnooze: h.smartSnooze,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(habitNotificationSettingsProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isSpecial = widget.habit.isSpecial;
    
    final iconColor = Color(widget.habit.colorValue);
    
    // App theme color - always use gold for UI elements
    const themeColor = _goldPrimary;
    const themeColorLight = _goldLight;

    // Background colors
    final bgColor = isSpecial
        ? (isDark ? const Color(0xFF1B1F26) : const Color(0xFFFFFEF9))
        : (isDark ? const Color(0xFF1C2026) : Colors.white);
    
    final cardGradientColors = isSpecial
        ? (isDark
            ? [const Color(0xFF252B35), const Color(0xFF1F252E), const Color(0xFF1A1F27)]
            : [const Color(0xFFFFFEF9), const Color(0xFFFFF9EC), const Color(0xFFFFFEF9)])
        : null;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 300),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomPadding),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: isSpecial ? null : bgColor,
          gradient: isSpecial && cardGradientColors != null
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: cardGradientColors,
                )
              : null,
          borderRadius: BorderRadius.circular(28),
          border: isSpecial
              ? Border.all(color: _goldPrimary.withOpacity(isDark ? 0.5 : 0.4), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: isSpecial 
                  ? _goldPrimary.withOpacity(isDark ? 0.2 : 0.15)
                  : Colors.black.withOpacity(0.25),
              blurRadius: isSpecial ? 20 : 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background icon decoration
            Positioned(
              right: -30,
              bottom: 40,
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (isSpecial ? themeColor : iconColor).withOpacity(isDark ? 0.12 : 0.08),
                    (isSpecial ? themeColorLight : iconColor).withOpacity(isDark ? 0.06 : 0.04),
                  ],
                ).createShader(bounds),
                child: Icon(
                  isSpecial ? Icons.star_rounded : (widget.habit.icon ?? Icons.repeat_rounded),
                  size: 140,
                  color: Colors.white,
                ),
              ),
            ),
            
            // Main content
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isSpecial
                            ? _goldPrimary.withOpacity(0.4)
                            : (isDark ? Colors.white24 : Colors.black12),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Habit content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Special badge
                        if (isSpecial) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _goldPrimary.withOpacity(0.25),
                                  _goldDark.withOpacity(0.12),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _goldPrimary.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: _goldPrimary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'SPECIAL',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: _goldPrimary,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Habit icon and title row
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: iconColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                widget.habit.icon ?? Icons.repeat_rounded,
                                color: iconColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.habit.title,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF1A1C1E),
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.repeat_rounded,
                                        size: 14,
                                        color: _goldPrimary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.habit.frequencyType,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _goldPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Description
                        if (widget.habit.description != null &&
                            widget.habit.description!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            widget.habit.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white60 : const Color(0xFF6E6E6E),
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        // "Why" factor (motivation), if provided
                        if (widget.habit.motivation != null &&
                            widget.habit.motivation!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '"${widget.habit.motivation!.trim()}"',
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF5A5A5A),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        const SizedBox(height: 16),
                        _buildStreakDisplay(isDark),
                      ],
                    ),
                  ),

                  // Divider
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                  ),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      children: [
                        // Primary row: Done + Quick Snooze
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _ModernButton(
                                icon: Icons.check_rounded,
                                label: 'Complete',
                                color: const Color(0xFF4CAF50),
                                isPrimary: true,
                                isLoading: _isProcessing,
                                onTap: _handleDone,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _ModernButton(
                                icon: Icons.snooze_rounded,
                                label: '${settings.defaultSnoozeDuration}m',
                                color: const Color(0xFF5C9CE6),
                                isPrimary: true,
                                onTap: () => _handleQuickSnooze(settings.defaultSnoozeDuration),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Secondary row: More, Skip
                        Row(
                          children: [
                            Expanded(
                              child: _ModernButton(
                                icon: Icons.more_time_rounded,
                                label: 'More',
                                color: const Color(0xFF5C9CE6),
                                isSmall: true,
                                onTap: _handleSnoozeOptions,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ModernButton(
                                icon: Icons.skip_next_rounded,
                                label: 'Skip',
                                color: const Color(0xFFE57373),
                                isSmall: true,
                                onTap: _handleSkip,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Dismiss option
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? Colors.white38 : Colors.black38,
                        ),
                        child: const Text(
                          'Dismiss',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
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

  Widget _buildStreakDisplay(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.local_fire_department_rounded,
            value: '${widget.habit.currentStreak}',
            label: 'Current',
            color: AppColorSchemes.primaryGold,
          ),
          _StatItem(
            icon: Icons.emoji_events_rounded,
            value: '${widget.habit.bestStreak}',
            label: 'Best',
            color: const Color(0xFF4CAF50),
          ),
          _StatItem(
            icon: Icons.check_circle_rounded,
            value: '${widget.habit.totalCompletions}',
            label: 'Total',
            color: const Color(0xFF5C9CE6),
          ),
        ],
      ),
    );
  }

  void _handleDone() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      await ref.read(habitNotifierProvider.notifier)
          .completeHabitForDate(widget.habit.id, DateTime.now());
      await ReminderManager().cancelRemindersForHabit(widget.habit.id);

      if (mounted) {
        Navigator.pop(context);
        _showSuccessSnackbar('Habit completed! 🎉', const Color(0xFF4CAF50));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorSnackbar('Failed to complete habit');
      }
    }
  }

  void _handleQuickSnooze(int minutes) async {
    HapticFeedback.lightImpact();
    final settings = ref.read(habitNotificationSettingsProvider);

    // Persist snooze state + history so Habit Details reflects it immediately.
    await _persistSnoozeToHabit(minutes, source: 'popup_quick');

    await NotificationService().snoozeNotification(
      taskId: widget.habit.id,
      title: widget.habit.title,
      body: widget.habit.description ?? 'Time for your habit!',
      payload: 'habit|${widget.habit.id}|snooze|$minutes|minutes',
      customDurationMinutes: minutes,
      settingsOverride: _mapHabitSettings(settings),
      notificationKindLabel: 'Habit',
      channelKeyOverride: settings.defaultChannel,
    );

    if (mounted) Navigator.pop(context);
    _showSuccessSnackbar('Snoozed for $minutes minutes', const Color(0xFF5C9CE6));
  }

  void _handleSnoozeOptions() async {
    HapticFeedback.lightImpact();
    final settings = ref.read(habitNotificationSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final minutes = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ModernSnoozeSheet(
        options: settings.snoozeOptions,
        defaultOption: settings.defaultSnoozeDuration,
        isDark: isDark,
      ),
    );

    if (minutes == null) return;
    if (!mounted) return;

    // Persist snooze state + history so Habit Details reflects it immediately.
    await _persistSnoozeToHabit(minutes, source: 'popup_options');

    await NotificationService().snoozeNotification(
      taskId: widget.habit.id,
      title: widget.habit.title,
      body: widget.habit.description ?? 'Time for your habit!',
      payload: 'habit|${widget.habit.id}|snooze|$minutes|minutes',
      customDurationMinutes: minutes,
      settingsOverride: _mapHabitSettings(settings),
      notificationKindLabel: 'Habit',
      channelKeyOverride: settings.defaultChannel,
    );

    if (mounted) Navigator.pop(context);
    _showSuccessSnackbar('Snoozed for ${_formatDuration(minutes)}', const Color(0xFF5C9CE6));
  }

  void _handleSkip() async {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => SkipReasonDialog(
        isDark: isDark,
        habitName: widget.habit.title,
      ),
    );

    if (reason != null && mounted) {
      try {
        await ref.read(habitNotifierProvider.notifier)
            .skipHabitForDate(widget.habit.id, DateTime.now(), reason: reason);
        await ReminderManager().cancelRemindersForHabit(widget.habit.id);
        
        if (mounted) {
          Navigator.pop(context);
          _showSuccessSnackbar('Habit skipped', const Color(0xFFE57373));
        }
      } catch (e) {
        if (mounted) _showErrorSnackbar('Failed to skip habit');
      }
    }
  }

  Future<void> _persistSnoozeToHabit(int minutes, {required String source}) async {
    try {
      final snoozedUntil = DateTime.now().add(Duration(minutes: minutes));
      
      // Build history list (append-only).
      List<Map<String, dynamic>> history = [];
      final rawHistory = (widget.habit.snoozeHistory ?? '').trim();
      if (rawHistory.isNotEmpty) {
        try {
          history = List<Map<String, dynamic>>.from(jsonDecode(rawHistory));
        } catch (_) {
          history = [];
        }
      }
      
      final now = DateTime.now();
      final occurrenceDate = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      history.add({
        'at': now.toIso8601String(),
        'minutes': minutes,
        'until': snoozedUntil.toIso8601String(),
        'occurrenceDate': occurrenceDate,
        'source': source,
      });
      
      final updatedHabit = widget.habit.copyWith(
        snoozedUntil: snoozedUntil,
        snoozeHistory: jsonEncode(history),
      );
      
      // IMPORTANT: `copyWith` returns a new object that is not attached to a Hive box,
      // so `.save()` would throw. Persist by updating the box via repository.
      await HabitRepository().updateHabit(updatedHabit);
      
      // Refresh habit list providers so details screen sees the new values.
      ref.read(habitNotifierProvider.notifier).loadHabits();
      
      debugPrint('⏰ HabitReminderPopup: Snooze persisted to habit (history=${history.length})');
    } catch (e) {
      debugPrint('⚠️ HabitReminderPopup: Failed to persist snooze: $e');
    }
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours hr';
    return '$hours hr $mins min';
  }

  void _showSuccessSnackbar(String message, Color color) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white38 : Colors.black38,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _ModernButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isPrimary;
  final bool isLoading;
  final bool isSmall;
  final VoidCallback onTap;

  const _ModernButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isPrimary = false,
    this.isLoading = false,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: isPrimary ? color : color.withOpacity(isDark ? 0.12 : 0.08),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: isSmall ? 14 : 16, 
              horizontal: 4
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(isPrimary ? Colors.white : color),
                    ),
                  )
                else
                  Icon(
                    icon,
                    color: isPrimary ? Colors.white : color,
                    size: isSmall ? 17 : 19,
                  ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: isSmall ? 12 : 13,
                      fontWeight: FontWeight.w800,
                      color: isPrimary ? Colors.white : color,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
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

class _ModernSnoozeSheet extends StatelessWidget {
  final List<int> options;
  final int defaultOption;
  final bool isDark;

  const _ModernSnoozeSheet({
    required this.options,
    required this.defaultOption,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2026) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5C9CE6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.snooze_rounded,
                    color: Color(0xFF5C9CE6),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Snooze for...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1C1E),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...options.map((minutes) {
                    final isDefault = minutes == defaultOption;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, minutes),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          child: Row(
                            children: [
                              Icon(
                                isDefault ? Icons.timer_rounded : Icons.timer_outlined,
                                color: isDefault ? const Color(0xFF5C9CE6) : (isDark ? Colors.white54 : Colors.black45),
                                size: 22,
                              ),
                              const SizedBox(width: 14),
                              Text(
                                _formatDuration(minutes),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isDefault ? FontWeight.w700 : FontWeight.w500,
                                  color: isDark ? Colors.white : const Color(0xFF1A1C1E),
                                ),
                              ),
                              if (isDefault) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5C9CE6).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Default',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF5C9CE6),
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: isDark ? Colors.white24 : Colors.black26,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        final customMinutes = await _showCustomSnoozeDialog(context);
                        if (customMinutes != null && context.mounted) {
                          Navigator.pop(context, customMinutes);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        child: Row(
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              color: isDark ? Colors.white54 : Colors.black45,
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'Custom…',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF1A1C1E),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: isDark ? Colors.white24 : Colors.black26,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: const SizedBox(height: 8),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes minutes';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    return '$hours hr $mins min';
  }

  Future<int?> _showCustomSnoozeDialog(BuildContext context) async {
    return await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CustomSnoozeSheet(isDark: isDark),
    );
  }
}

class _CustomSnoozeSheet extends StatefulWidget {
  final bool isDark;
  const _CustomSnoozeSheet({required this.isDark});

  @override
  State<_CustomSnoozeSheet> createState() => _CustomSnoozeSheetState();
}

class _CustomSnoozeSheetState extends State<_CustomSnoozeSheet> {
  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _hoursController = TextEditingController();
    _minutesController = TextEditingController();
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? const Color(0xFF1C2026) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1C1E);
    final subText = isDark ? Colors.white70 : Colors.black54;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Custom snooze',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Enter hours/minutes. Example: 1 hour 30 minutes.',
                  style: TextStyle(color: subText, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _hoursController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Hours',
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: TextStyle(color: textColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _minutesController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Minutes',
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: TextStyle(color: textColor),
                      ),
                    ),
                  ],
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorText!,
                    style: const TextStyle(
                      color: Color(0xFFE57373),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: subText,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5C9CE6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          final h = int.tryParse(_hoursController.text.trim()) ?? 0;
                          final m = int.tryParse(_minutesController.text.trim()) ?? 0;
                          final total = (h * 60) + m;

                          if (total <= 0) {
                            setState(() => _errorText = 'Please enter a duration greater than 0.');
                            return;
                          }
                          if (total > 24 * 60) {
                            setState(() => _errorText = 'Max allowed is 24 hours.');
                            return;
                          }
                          Navigator.pop(context, total);
                        },
                        child: const Text('Set snooze', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkipReasonSheet extends StatefulWidget {
  final String habitTitle;
  final bool isDark;

  const _SkipReasonSheet({
    required this.habitTitle,
    required this.isDark,
  });

  @override
  State<_SkipReasonSheet> createState() => _SkipReasonSheetState();
}

class _SkipReasonSheetState extends State<_SkipReasonSheet> {
  final TextEditingController _customReasonController = TextEditingController();
  bool _showCustomInput = false;

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final reasons = [
      'Too busy today',
      'Not feeling well',
      'Taking a rest day',
      'Traveling',
      'Other priorities',
    ];

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomPadding),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1C2026) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE57373).withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE57373).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.skip_next_rounded,
                        color: Color(0xFFE57373),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Skip this habit?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: widget.isDark ? Colors.white : const Color(0xFF1A1C1E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.habitTitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: widget.isDark ? Colors.white54 : Colors.black45,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (!_showCustomInput) ...[
            ...reasons.map((reason) => _buildReasonOption(
              icon: Icons.info_outline_rounded,
              text: reason,
              color: const Color(0xFFE57373),
            )),
            _buildReasonOption(
              icon: Icons.edit_rounded,
              text: 'Other reason...',
              color: AppColorSchemes.primaryGold,
              onTap: () => setState(() => _showCustomInput = true),
            ),
          ],

          if (_showCustomInput) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _customReasonController,
                    autofocus: true,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Enter your reason...',
                      hintStyle: TextStyle(
                        color: widget.isDark ? Colors.white38 : Colors.black38,
                      ),
                      filled: true,
                      fillColor: widget.isDark 
                          ? Colors.white.withOpacity(0.05) 
                          : Colors.black.withOpacity(0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => setState(() => _showCustomInput = false),
                          child: Text(
                            'Back',
                            style: TextStyle(
                              color: widget.isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final reason = _customReasonController.text.trim();
                            if (reason.isNotEmpty) {
                              Navigator.pop(context, reason);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE57373),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Submit',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          SafeArea(
            top: false,
            child: const SizedBox(height: 8),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonOption({
    required IconData icon,
    required String text,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => Navigator.pop(context, text),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: widget.isDark ? Colors.white : const Color(0xFF1A1C1E),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: widget.isDark ? Colors.white24 : Colors.black26,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
