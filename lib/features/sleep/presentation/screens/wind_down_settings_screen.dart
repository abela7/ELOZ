import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/notifications/models/universal_notification.dart';
import '../../../../core/notifications/services/universal_notification_display_helper.dart';
import '../../../../core/notifications/services/universal_notification_scheduler.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../../../features/notifications_hub/presentation/widgets/universal_notification_creator_sheet.dart';
import '../../data/services/wind_down_schedule_service.dart';
import '../../notifications/sleep_notification_creator_context.dart';
import '../../notifications/wind_down_notification_repository.dart';
import '../providers/sleep_providers.dart';

/// Wind-Down reminder settings.
///
/// User sets bedtime per day and reminder offset (30 min, 1 hr, etc.).
/// All data is prepared for Notification Hub integration.
class WindDownSettingsScreen extends ConsumerStatefulWidget {
  const WindDownSettingsScreen({super.key});

  @override
  ConsumerState<WindDownSettingsScreen> createState() =>
      _WindDownSettingsScreenState();
}

class _WindDownSettingsScreenState extends ConsumerState<WindDownSettingsScreen> {
  bool _enabled = false;
  int _reminderOffsetMinutes = 30;
  final Map<int, TimeOfDay?> _bedtimes = {1: null, 2: null, 3: null, 4: null, 5: null, 6: null, 7: null};
  bool _isLoading = true;
  bool _isSaving = false;

  static const List<int> _weekdays = [1, 2, 3, 4, 5, 6, 7];

  static const Map<int, String> _weekdayLabels = {
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(windDownScheduleServiceProvider);
    final enabled = await service.getEnabled();
    final offset = await service.getReminderOffsetMinutes();
    final schedule = await service.getFullSchedule();

    if (mounted) {
      setState(() {
        _enabled = enabled;
        _reminderOffsetMinutes = offset;
        for (final e in schedule.entries) {
          _bedtimes[e.key] = e.value;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    final service = ref.read(windDownScheduleServiceProvider);
    await service.setEnabled(_enabled);
    await service.setReminderOffsetMinutes(_reminderOffsetMinutes);
    await service.saveFullSchedule(Map.from(_bedtimes));

    final repo = WindDownNotificationRepository();
    await repo.init();
    if (_enabled) {
      await repo.resyncFromSchedule();
    } else {
      final existing = await repo.getAll(moduleId: 'sleep', section: 'winddown');
      for (final n in existing) {
        await UniversalNotificationScheduler().cancelForNotification(n);
        await repo.delete(n.id);
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wind-down settings saved'),
          backgroundColor: AppColors.gold,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickTime(int weekday) async {
    final current = _bedtimes[weekday] ?? const TimeOfDay(hour: 22, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.gold,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _bedtimes[weekday] = picked);
      await _save();
    }
  }

  void _clearDay(int weekday) {
    setState(() => _bedtimes[weekday] = null);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(child: _buildContent(context, isDark))
          : _buildContent(context, isDark),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Wind-Down Reminders'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(isDark),
                  const SizedBox(height: 24),

                  _buildEnableCard(isDark),
                  const SizedBox(height: 24),

                  _buildReminderOffsetCard(isDark),
                  const SizedBox(height: 24),

                  _buildSectionHeader('Bedtime by Day', isDark),
                  const SizedBox(height: 8),
                  Text(
                    'Set your target bedtime for each day. Different days can have different times.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 16),

                  ..._weekdays.map((w) => _buildDayRow(isDark, w)),
                  const SizedBox(height: 32),

                  _buildWindDownRemindersSection(isDark),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    final count = _bedtimes.values.where((t) => t != null).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.gold.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackOpacity004,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.bedtime_rounded,
              color: AppColors.gold,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reminder before bedtime',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _enabled
                      ? '$count day${count == 1 ? '' : 's'} configured • ${_reminderOffsetMinutes} min before'
                      : 'Off',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnableCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackOpacity004,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enable Wind-Down Reminders',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Get notified before your set bedtime',
                  style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
            ),
          ),
          Switch(
            value: _enabled,
            onChanged: (v) {
              setState(() => _enabled = v);
              _save();
            },
            activeColor: AppColors.gold,
          ),
        ],
      ),
    );
  }

  Widget _buildReminderOffsetCard(bool isDark) {
    final presets = WindDownScheduleService.reminderOffsetPresets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reminder time before bedtime',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((mins) {
            final isSelected = _reminderOffsetMinutes == mins;
            final label = mins >= 60
                ? '${mins ~/ 60}h'
                : '${mins}m';
            return GestureDetector(
              onTap: () {
                setState(() => _reminderOffsetMinutes = mins);
                _save();
                HapticFeedback.lightImpact();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.goldOpacity03
                      : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.gold : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.gold : (isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.gold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDayRow(bool isDark, int weekday) {
    final time = _bedtimes[weekday];
    final label = _weekdayLabels[weekday] ?? 'Day $weekday';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackOpacity004,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _pickTime(weekday),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.06) : AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 18,
                      color: time != null ? AppColors.gold : (isDark ? Colors.white38 : Colors.black38),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      time != null
                          ? time.format(context)
                          : 'Not set',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: time != null
                            ? (isDark ? Colors.white : Colors.black87)
                            : (isDark ? Colors.white38 : Colors.black38),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (time != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => _clearDay(weekday),
              color: isDark ? Colors.white38 : Colors.black38,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
        ],
      ),
    );
  }

  Future<List<UniversalNotification>> _loadWindDownReminders(
    WindDownNotificationRepository repo,
  ) async {
    await repo.init();
    return repo.getAll(
      moduleId: 'sleep',
      section: 'winddown',
    );
  }

  Widget _buildWindDownRemindersSection(bool isDark) {
    final repo = WindDownNotificationRepository();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackOpacity004,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_rounded,
                size: 20,
                color: AppColors.gold,
              ),
              const SizedBox(width: 10),
              Text(
                'Wind-Down Reminders',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Set title, body, icon, and actions. Fires every day before your '
            'configured bedtime.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<UniversalNotification>>(
            future: _loadWindDownReminders(repo),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Could not load reminders',
                    style: TextStyle(
                      fontSize: 14,
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 48,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final reminders = snapshot.data!;
              final displayReminders = reminders.isEmpty
                  ? <UniversalNotification>[]
                  : [reminders.first];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (reminders.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'No reminders yet. Add one below.',
                        style: TextStyle(
                          fontSize: 13,
                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                        ),
                      ),
                    ),
                  ...displayReminders.map((n) => _buildWindDownReminderTile(n, isDark, repo, reminders.length)),
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (_bedtimes.values.every((t) => t == null)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Set at least one bedtime above before adding a reminder.',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      HapticFeedback.selectionClick();
                      await UniversalNotificationCreatorSheet.show(
                        context,
                        creatorContext: SleepNotificationCreatorContext.forWindDown(
                          reminderOffsetMinutes: _reminderOffsetMinutes,
                          bedtimesByWeekday: Map.from(_bedtimes),
                        ),
                        existing: null,
                        repository: repo,
                      );
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Reminder'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      side: BorderSide(color: AppColors.gold.withOpacity(0.6)),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWindDownReminderTile(
    UniversalNotification n,
    bool isDark,
    WindDownNotificationRepository repo,
    int dayCount,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                await UniversalNotificationCreatorSheet.show(
                  context,
                  creatorContext: SleepNotificationCreatorContext.forWindDown(
                    reminderOffsetMinutes: _reminderOffsetMinutes,
                    bedtimesByWeekday: Map.from(_bedtimes),
                  ),
                  existing: n,
                  repository: repo,
                );
                if (mounted) setState(() {});
              },
              borderRadius: BorderRadius.circular(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FutureBuilder<String>(
                    future: resolveUniversalNotificationDisplayTitle(n),
                    builder: (_, snap) {
                      final title = snap.hasData
                          ? snap.data!
                          : n.titleTemplate.replaceAll(RegExp(r'\{[^}]*\}'), '…');
                      return Text(
                        title.isNotEmpty ? title : 'Reminder',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dayCount > 1
                        ? '$_reminderOffsetMinutes min before bedtime • $dayCount days'
                        : n.timingDescription,
                    style: TextStyle(
                      fontSize: 11,
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: Colors.red.withOpacity(0.8),
            ),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Wind-Down Reminder?'),
                  content: const Text(
                    'This will remove this wind-down reminder for all days.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirmed == true && mounted) {
                final all =
                    await repo.getAll(moduleId: 'sleep', section: 'winddown');
                for (final x in all) {
                  await UniversalNotificationScheduler().cancelForNotification(x);
                  await repo.delete(x.id);
                }
                setState(() {});
              }
            },
          ),
        ],
      ),
    );
  }
}
