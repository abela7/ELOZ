import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/color_schemes.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/bill.dart';
import '../../data/models/bill_notification_profile.dart';
import '../../data/repositories/bill_repository.dart';
import '../../data/services/bill_notification_profile_service.dart';
import '../../notifications/finance_notification_contract.dart';
import '../../notifications/finance_notification_scheduler.dart';

class BillNotificationProfilesScreen extends StatefulWidget {
  const BillNotificationProfilesScreen({super.key});

  @override
  State<BillNotificationProfilesScreen> createState() =>
      _BillNotificationProfilesScreenState();
}

class _BillNotificationProfilesScreenState
    extends State<BillNotificationProfilesScreen> {
  static const List<int> _daysBeforeOptions = <int>[
    0,
    1,
    2,
    3,
    5,
    7,
    10,
    14,
    21,
    30,
  ];

  static const List<_Choice> _templateOptions = <_Choice>[
    _Choice(FinanceNotificationContract.templateBillDue, 'Standard Due Alert'),
    _Choice(
      FinanceNotificationContract.templateBillFriendly,
      'Friendly Reminder',
    ),
    _Choice(FinanceNotificationContract.templateBillAction, 'Action Prompt'),
    _Choice(FinanceNotificationContract.templateBillCompact, 'Compact Message'),
  ];

  static const List<_Choice> _channelOptions = <_Choice>[
    _Choice('auto', 'Auto (Use Hub Type)'),
    _Choice('task_reminders', 'Task Reminders Channel'),
    _Choice('urgent_reminders', 'Urgent Reminders Channel'),
    _Choice('silent_reminders', 'Silent Reminders Channel'),
  ];

  static const List<_Choice> _soundOptions = <_Choice>[
    _Choice('auto', 'Auto (Use Hub Type)'),
    _Choice('default', 'Default Sound'),
    _Choice('alarm', 'Alarm Sound'),
    _Choice('silent', 'Silent (No Sound)'),
  ];

  static const List<_Choice> _typeOptions = <_Choice>[
    _Choice('auto', 'Auto (Due Logic)'),
    _Choice(FinanceNotificationContract.typePaymentDue, 'Payment Due Alert'),
    _Choice(FinanceNotificationContract.typeReminder, 'Finance Reminder'),
    _Choice(
      FinanceNotificationContract.typeSummary,
      'Finance Summary (Low Priority)',
    ),
  ];

  final BillRepository _billRepository = BillRepository();
  final BillNotificationProfileService _profileService =
      BillNotificationProfileService();
  final FinanceNotificationScheduler _scheduler =
      FinanceNotificationScheduler();

  List<Bill> _bills = <Bill>[];
  Map<String, BillNotificationProfile> _profiles =
      <String, BillNotificationProfile>{};
  bool _loading = true;
  bool _syncing = false;
  bool _queuedSilentSync = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bills = await _billRepository.getActiveBills();
      final profiles = await _profileService.loadAll();
      if (!mounted) return;

      final sorted = List<Bill>.from(bills)..sort(_sortBillsByDueDate);
      setState(() {
        _bills = sorted;
        _profiles = profiles;
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '$error';
      });
    }
  }

  int _sortBillsByDueDate(Bill a, Bill b) {
    final aDate = a.nextDueDate;
    final bDate = b.nextDueDate;
    if (aDate == null && bDate == null) {
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }
    if (aDate == null) return 1;
    if (bDate == null) return -1;

    final aKey = DateTime(aDate.year, aDate.month, aDate.day);
    final bKey = DateTime(bDate.year, bDate.month, bDate.day);
    final dateCompare = aKey.compareTo(bKey);
    if (dateCompare != 0) {
      return dateCompare;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  BillNotificationProfile _profileFor(String billId) {
    return _profiles[billId] ?? BillNotificationProfile(billId: billId);
  }

  Future<void> _saveBill(Bill bill) async {
    await _billRepository.updateBill(bill);
    if (!mounted) return;
    setState(() {
      final next = List<Bill>.from(_bills);
      final index = next.indexWhere((entry) => entry.id == bill.id);
      if (index >= 0) {
        next[index] = bill;
      } else {
        next.add(bill);
      }
      next.sort(_sortBillsByDueDate);
      _bills = next;
    });
    await _syncNow(showSnackBar: false);
  }

  bool _isDefaultProfile(BillNotificationProfile profile) {
    return profile.templateKey == FinanceNotificationContract.templateBillDue &&
        (profile.channelKey == null || profile.channelKey!.isEmpty) &&
        (profile.soundKey == null || profile.soundKey!.isEmpty) &&
        (profile.typeOverride == null || profile.typeOverride!.isEmpty);
  }

  Future<void> _saveProfile(BillNotificationProfile profile) async {
    if (_isDefaultProfile(profile)) {
      await _profileService.removeProfile(profile.billId);
      if (!mounted) return;
      setState(() {
        final next = Map<String, BillNotificationProfile>.from(_profiles);
        next.remove(profile.billId);
        _profiles = next;
      });
    } else {
      await _profileService.saveProfile(profile);
      if (!mounted) return;
      setState(() {
        final next = Map<String, BillNotificationProfile>.from(_profiles);
        next[profile.billId] = profile;
        _profiles = next;
      });
    }

    await _syncNow(showSnackBar: false);
  }

  Future<void> _syncNow({bool showSnackBar = true}) async {
    if (_syncing) {
      if (!showSnackBar) {
        _queuedSilentSync = true;
      }
      return;
    }

    if (mounted) {
      setState(() => _syncing = true);
    }

    try {
      final result = await _scheduler.syncSchedules();
      if (!mounted || !showSnackBar) return;

      final billScheduled =
          result.scheduledBySection[FinanceNotificationContract.sectionBills] ??
          0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bills synced: $billScheduled bill schedules, '
            '${result.scheduled} total, ${result.cancelled} cleared',
          ),
          backgroundColor: AppColorSchemes.primaryGold,
        ),
      );
    } catch (error) {
      if (!mounted || !showSnackBar) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }

    if (_queuedSilentSync) {
      _queuedSilentSync = false;
      await _syncNow(showSnackBar: false);
    }
  }

  String _normalizedChoice(
    String? value,
    List<_Choice> options, {
    required String fallback,
  }) {
    if (value == null || value.trim().isEmpty) {
      return fallback;
    }

    final normalized = value.trim();
    final exists = options.any((option) => option.value == normalized);
    return exists ? normalized : fallback;
  }

  Future<void> _updateReminderEnabled(Bill bill, bool enabled) async {
    HapticFeedback.selectionClick();
    final nextBill = bill.copyWith(reminderEnabled: enabled);
    await _saveBill(nextBill);
  }

  Future<void> _updateReminderDays(Bill bill, int daysBefore) async {
    if (daysBefore == bill.reminderDaysBefore) return;
    HapticFeedback.selectionClick();
    final nextBill = bill.copyWith(reminderDaysBefore: daysBefore);
    await _saveBill(nextBill);
  }

  Future<void> _updateTemplate(Bill bill, String templateKey) async {
    HapticFeedback.selectionClick();
    final profile = _profileFor(bill.id).copyWith(templateKey: templateKey);
    await _saveProfile(profile);
  }

  Future<void> _updateChannel(Bill bill, String channelKey) async {
    HapticFeedback.selectionClick();
    final current = _profileFor(bill.id);
    final next = channelKey == 'auto'
        ? current.copyWith(clearChannel: true)
        : current.copyWith(channelKey: channelKey);
    await _saveProfile(next);
  }

  Future<void> _updateSound(Bill bill, String soundKey) async {
    HapticFeedback.selectionClick();
    final current = _profileFor(bill.id);
    final next = soundKey == 'auto'
        ? current.copyWith(clearSound: true)
        : current.copyWith(soundKey: soundKey);
    await _saveProfile(next);
  }

  Future<void> _updateType(Bill bill, String typeKey) async {
    HapticFeedback.selectionClick();
    final current = _profileFor(bill.id);
    final next = typeKey == 'auto'
        ? current.copyWith(clearTypeOverride: true)
        : current.copyWith(typeOverride: typeKey);
    await _saveProfile(next);
  }

  String _dateLabel(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _dueStatusLabel(Bill bill) {
    final due = bill.nextDueDate;
    if (due == null) return 'No due date';

    final now = DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(due.year, due.month, due.day);
    final days = dueDate.difference(nowDate).inDays;

    if (days < 0) {
      final overdueDays = days.abs();
      return 'Overdue by $overdueDays day${overdueDays == 1 ? '' : 's'}';
    }
    if (days == 0) {
      return 'Due today';
    }
    return 'Due in $days day${days == 1 ? '' : 's'}';
  }

  IconData _billIcon(Bill bill) {
    if (bill.iconCodePoint != null) {
      return IconData(
        bill.iconCodePoint!,
        fontFamily: bill.iconFontFamily ?? 'MaterialIcons',
        fontPackage: bill.iconFontPackage,
      );
    }
    return bill.type == 'subscription'
        ? Icons.subscriptions_rounded
        : Icons.receipt_long_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Scaffold(
      backgroundColor: isDark ? Colors.transparent : const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Bills Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Sync schedules',
            onPressed: _syncing ? null : () => _syncNow(showSnackBar: true),
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _card(
                  isDark,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: Theme.of(context).colorScheme.error,
                          size: 30,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Failed to load bills notifications',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _loadError = null;
                            });
                            _load();
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                _instructionCard(isDark),
                const SizedBox(height: 16),
                if (_bills.isEmpty) _emptyStateCard(isDark),
                if (_bills.isNotEmpty)
                  ..._bills.map((bill) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _billCard(isDark, bill),
                    );
                  }),
              ],
            ),
    );

    return isDark ? DarkGradient.wrap(child: content) : content;
  }

  Widget _instructionCard(bool isDark) {
    return _card(
      isDark,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How Bills Notifications Work',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '1. Enable reminder per bill or subscription.\n'
              '2. Select days-before timing.\n'
              '3. Choose template, channel, sound, and type.\n'
              '4. Settings auto-sync to Notification Hub after changes.\n'
              '5. Use Sync to force refresh immediately.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyStateCard(bool isDark) {
    return _card(
      isDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColorSchemes.primaryGold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: AppColorSchemes.primaryGold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No active bills or subscriptions found. Create one in Bills & Subscriptions first.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _billCard(bool isDark, Bill bill) {
    final profile = _profileFor(bill.id);
    final templateValue = _normalizedChoice(
      profile.templateKey,
      _templateOptions,
      fallback: FinanceNotificationContract.templateBillDue,
    );
    final channelValue = _normalizedChoice(
      profile.channelKey,
      _channelOptions,
      fallback: 'auto',
    );
    final soundValue = _normalizedChoice(
      profile.soundKey,
      _soundOptions,
      fallback: 'auto',
    );
    final typeValue = _normalizedChoice(
      profile.typeOverride,
      _typeOptions,
      fallback: 'auto',
    );

    final cardIconColor = Color(bill.colorValue);
    final reminderEnabled = bill.reminderEnabled;
    final dayOptions = <int>[..._daysBeforeOptions];
    if (!dayOptions.contains(bill.reminderDaysBefore)) {
      dayOptions.add(bill.reminderDaysBefore);
    }
    dayOptions.sort();

    return _card(
      isDark,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: cardIconColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_billIcon(bill), color: cardIconColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${bill.currency} ${bill.defaultAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: reminderEnabled,
                  activeTrackColor: AppColorSchemes.primaryGold,
                  onChanged: (value) => _updateReminderEnabled(bill, value),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metaChip(
                  isDark: isDark,
                  icon: Icons.calendar_today_rounded,
                  text: _dueStatusLabel(bill),
                ),
                _metaChip(
                  isDark: isDark,
                  icon: Icons.event_rounded,
                  text: bill.nextDueDate == null
                      ? 'No due date'
                      : _dateLabel(bill.nextDueDate!),
                ),
                _metaChip(
                  isDark: isDark,
                  icon: Icons.category_rounded,
                  text: bill.type == 'subscription' ? 'Subscription' : 'Bill',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Opacity(
              opacity: reminderEnabled ? 1 : 0.55,
              child: IgnorePointer(
                ignoring: !reminderEnabled,
                child: Column(
                  children: [
                    _dropdownField<int>(
                      isDark: isDark,
                      icon: Icons.schedule_send_rounded,
                      label: 'Days Before Due Date',
                      value: bill.reminderDaysBefore,
                      items: dayOptions
                          .map(
                            (days) => DropdownMenuItem<int>(
                              value: days,
                              child: Text(
                                days == 0
                                    ? 'On due date'
                                    : '$days day${days == 1 ? '' : 's'} before',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        _updateReminderDays(bill, value);
                      },
                    ),
                    const SizedBox(height: 10),
                    _dropdownField<String>(
                      isDark: isDark,
                      icon: Icons.article_rounded,
                      label: 'Notification Template',
                      value: templateValue,
                      items: _templateOptions
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option.value,
                              child: Text(option.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        _updateTemplate(bill, value);
                      },
                    ),
                    const SizedBox(height: 10),
                    _dropdownField<String>(
                      isDark: isDark,
                      icon: Icons.campaign_rounded,
                      label: 'Notification Channel',
                      value: channelValue,
                      items: _channelOptions
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option.value,
                              child: Text(option.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        _updateChannel(bill, value);
                      },
                    ),
                    const SizedBox(height: 10),
                    _dropdownField<String>(
                      isDark: isDark,
                      icon: Icons.music_note_rounded,
                      label: 'Notification Sound',
                      value: soundValue,
                      items: _soundOptions
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option.value,
                              child: Text(option.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        _updateSound(bill, value);
                      },
                    ),
                    const SizedBox(height: 10),
                    _dropdownField<String>(
                      isDark: isDark,
                      icon: Icons.flag_rounded,
                      label: 'Notification Type Routing',
                      value: typeValue,
                      items: _typeOptions
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option.value,
                              child: Text(option.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        _updateType(bill, value);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip({
    required bool isDark,
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isDark ? Colors.white70 : Colors.black54),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdownField<T>({
    required bool isDark,
    required IconData icon,
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
        prefixIcon: Icon(icon, size: 19, color: AppColorSchemes.primaryGold),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColorSchemes.primaryGold,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      dropdownColor: isDark
          ? const Color(0xFF2A2D3A)
          : Theme.of(context).colorScheme.surface,
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _card(bool isDark, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: child,
    );
  }
}

class _Choice {
  final String value;
  final String label;

  const _Choice(this.value, this.label);
}
