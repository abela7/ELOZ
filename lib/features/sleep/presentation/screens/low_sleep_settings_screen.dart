import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/notifications/models/universal_notification.dart';
import '../../../../core/notifications/services/universal_notification_scheduler.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../data/services/low_sleep_reminder_service.dart';
import '../../notifications/low_sleep_notification_repository.dart';
import '../../notifications/sleep_notification_contract.dart';
import '../providers/sleep_providers.dart';

/// Low Sleep Reminder settings.
///
/// Same flow as Wind-Down: user configures → we save a UniversalNotification
/// definition → syncAll schedules it. The scheduler computes due from the
/// latest sleep record (wake time + N hours when sleep < threshold).
class LowSleepSettingsScreen extends ConsumerStatefulWidget {
  const LowSleepSettingsScreen({super.key});

  @override
  ConsumerState<LowSleepSettingsScreen> createState() =>
      _LowSleepSettingsScreenState();
}

class _LowSleepSettingsScreenState extends ConsumerState<LowSleepSettingsScreen> {
  bool _enabled = false;
  double _threshold = 6.0;
  double _hoursAfterWake = 2.0;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(lowSleepReminderServiceProvider);
    final enabled = await service.isEnabled();
    final threshold = await service.getThresholdHours();
    final hoursAfterWake = await service.getHoursAfterWake();

    if (mounted) {
      setState(() {
        _enabled = enabled;
        _threshold = threshold;
        _hoursAfterWake = hoursAfterWake;
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    final service = ref.read(lowSleepReminderServiceProvider);
    await service.setEnabled(_enabled);
    await service.setThresholdHours(_threshold);
    await service.setHoursAfterWake(_hoursAfterWake);

    final repo = LowSleepNotificationRepository();
    await repo.init();

    if (_enabled) {
      final template = UniversalNotification(
        moduleId: SleepNotificationContract.moduleId,
        section: SleepNotificationContract.sectionLowSleep,
        entityId: SleepNotificationContract.entityLowSleep,
        entityName: 'Low Sleep Reminder',
        titleTemplate: 'Low sleep alert',
        bodyTemplate:
            'You slept only {sleepHours} hours last night. '
            'Consider an earlier bedtime tonight.',
        typeId: 'regular',
        timing: 'after_due',
        timingValue: _hoursAfterWake.floor(),
        timingUnit: 'hours',
        hour: 0,
        minute: 0,
        enabled: true,
      );
      await repo.save(template);
      unawaited(UniversalNotificationScheduler().syncAll());
    } else {
      await repo.deleteAll();
    }

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Low sleep reminder settings saved'),
          backgroundColor: AppColors.gold,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
        title: const Text('Low Sleep Reminder'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : () => _save(),
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(_isSaving ? 'Saving...' : 'Save'),
            style: TextButton.styleFrom(foregroundColor: AppColors.gold),
          ),
        ],
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
                  if (_enabled) ...[
                    _buildThresholdCard(isDark),
                    const SizedBox(height: 24),
                    _buildHoursAfterWakeCard(isDark),
                    const SizedBox(height: 24),
                  ],
                  _buildInfoCard(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
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
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Low Sleep Reminder',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Get reminded when you log sleep below your threshold. '
                  'Same flow as Wind-Down: sync-driven, managed by Notification Hub.',
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
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enable Low Sleep Reminder',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Notify when logged sleep is below your threshold',
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
              HapticFeedback.lightImpact();
              setState(() => _enabled = v);
            },
            activeColor: AppColors.gold,
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdCard(bool isDark) {
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
          Text(
            'Notify when sleep is below',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<double>(
            value: LowSleepReminderService.thresholdOptions.contains(_threshold)
                ? _threshold
                : LowSleepReminderService.thresholdOptions.first,
            items: LowSleepReminderService.thresholdOptions
                .map((h) => DropdownMenuItem(
                      value: h,
                      child: Text('${h.toInt()} hours'),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                HapticFeedback.selectionClick();
                setState(() => _threshold = v);
              }
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoursAfterWakeCard(bool isDark) {
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
          Text(
            'Remind me',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<double>(
            value: LowSleepReminderService.hoursAfterWakeOptions
                    .contains(_hoursAfterWake)
                ? _hoursAfterWake
                : LowSleepReminderService.hoursAfterWakeOptions.first,
            items: LowSleepReminderService.hoursAfterWakeOptions
                .map((h) => DropdownMenuItem(
                      value: h,
                      child: Text('${h.toInt()} hour(s) after I wake up'),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                HapticFeedback.selectionClick();
                setState(() => _hoursAfterWake = v);
              }
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'When you log sleep that is below your threshold, a reminder '
              'is scheduled for X hours after your wake time. Sync runs on '
              'app start, resume, and after saving a sleep log.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
