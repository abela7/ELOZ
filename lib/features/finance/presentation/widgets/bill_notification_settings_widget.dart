import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/notifications/notifications.dart';
import '../../../notifications_hub/presentation/screens/hub_module_detail_page.dart';
import '../../data/models/bill.dart';
import '../../data/models/bill_notification_profile.dart';
import '../../notifications/finance_notification_contract.dart';

/// Simplified bill notification settings.
///
/// The user only chooses:
///   1. ON / OFF
///   2. Notification type (Upcoming, Tomorrow, Due Today, Overdue)
///   3. When (days before + preferred time)
///
/// All system-level config (channel, sound, vibration, alarm mode) lives
/// exclusively in the Notification Hub's Module Detail page.
class BillNotificationSettingsWidget extends StatefulWidget {
  final Bill bill;
  final BillNotificationProfile? profile;
  final Function(BillNotificationProfile) onProfileChanged;
  final bool isDark;

  const BillNotificationSettingsWidget({
    super.key,
    required this.bill,
    this.profile,
    required this.onProfileChanged,
    required this.isDark,
  });

  @override
  State<BillNotificationSettingsWidget> createState() =>
      _BillNotificationSettingsWidgetState();
}

class _BillNotificationSettingsWidgetState
    extends State<BillNotificationSettingsWidget> {
  late bool _enabled;
  late int _daysBefore;
  late TimeOfDay? _preferredTime;
  late String _notificationType;

  static const _gold = Color(0xFFCDAF56);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final profile = widget.profile;
    _enabled = widget.bill.reminderEnabled;
    _daysBefore = widget.bill.reminderDaysBefore;
    _preferredTime = profile?.preferredTime;
    _notificationType = profile?.typeOverride ?? _autoType();
  }

  /// Auto-select the most appropriate type based on days-before.
  String _autoType() {
    if (_daysBefore == 0) return FinanceNotificationContract.typePaymentDue;
    if (_daysBefore == 1) return FinanceNotificationContract.typeBillTomorrow;
    return FinanceNotificationContract.typeBillUpcoming;
  }

  void _save() {
    widget.onProfileChanged(
      BillNotificationProfile(
        billId: widget.bill.id,
        reminderDaysBefore: _daysBefore,
        preferredTime: _preferredTime,
        typeOverride: _notificationType,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (dark ? Colors.white : Colors.black).withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(dark),
          if (_enabled) ...[
            Divider(
              height: 1,
              color: (dark ? Colors.white : Colors.black).withOpacity(0.06),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTypeSelector(dark),
                  const SizedBox(height: 20),
                  _buildWhenSelector(dark),
                  const SizedBox(height: 20),
                  _buildHubLink(dark),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Header (ON/OFF toggle)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool dark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (_enabled ? _gold : Colors.grey).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _enabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              color: _enabled ? _gold : (dark ? Colors.white38 : Colors.black38),
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Reminders',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: dark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _enabled
                      ? '$_daysBefore day${_daysBefore == 1 ? '' : 's'} before · ${_preferredTime?.format(context) ?? '9:00 AM'}'
                      : 'Tap to enable',
                  style: TextStyle(
                    fontSize: 12,
                    color: dark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _enabled,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              setState(() => _enabled = val);
              _save();
            },
            activeColor: _gold,
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Notification type selector (just pick one)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildTypeSelector(bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.campaign_rounded, 'Notification Type', dark),
        const SizedBox(height: 4),
        Text(
          'Sound, channel & delivery managed in Notification Hub',
          style: TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: dark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 12),
        ..._typeChoices.map((t) => _buildTypeChip(t, dark)),
      ],
    );
  }

  static const _typeChoices = [
    _TypeOption(
      id: FinanceNotificationContract.typeBillUpcoming,
      name: 'Upcoming',
      desc: 'Regular reminder',
      icon: Icons.notifications_rounded,
    ),
    _TypeOption(
      id: FinanceNotificationContract.typeBillTomorrow,
      name: 'Due Tomorrow',
      desc: 'Higher priority',
      icon: Icons.notification_important_rounded,
    ),
    _TypeOption(
      id: FinanceNotificationContract.typePaymentDue,
      name: 'Due Today',
      desc: 'Urgent',
      icon: Icons.priority_high_rounded,
    ),
    _TypeOption(
      id: FinanceNotificationContract.typeBillOverdue,
      name: 'Overdue',
      desc: 'Critical alarm',
      icon: Icons.alarm_rounded,
    ),
  ];

  Widget _buildTypeChip(_TypeOption t, bool dark) {
    final sel = _notificationType == t.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _notificationType = t.id);
          _save();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: sel
                ? _gold.withOpacity(0.12)
                : (dark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.025)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? _gold : (dark ? Colors.white12 : Colors.black12),
              width: sel ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(t.icon, size: 20, color: sel ? _gold : (dark ? Colors.white54 : Colors.black54)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sel ? _gold : (dark ? Colors.white : Colors.black87),
                      ),
                    ),
                    Text(
                      t.desc,
                      style: TextStyle(
                        fontSize: 11,
                        color: dark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
              if (sel)
                const Icon(Icons.check_circle_rounded, size: 20, color: _gold),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // When selector (days before + preferred time)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildWhenSelector(bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.schedule_rounded, 'When to Notify', dark),
        const SizedBox(height: 12),
        // Days chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [1, 3, 7, 14, 30].map((d) {
            final sel = _daysBefore == d;
            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _daysBefore = d;
                  // Auto-adjust type on day change
                  _notificationType = _autoType();
                });
                _save();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: sel
                      ? _gold.withOpacity(0.12)
                      : (dark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.025)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel ? _gold : (dark ? Colors.white12 : Colors.black12),
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  '$d day${d == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sel ? _gold : (dark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Time picker
        InkWell(
          onTap: _pickTime,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: dark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.025),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: dark ? Colors.white12 : Colors.black12),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded, size: 18, color: dark ? Colors.white54 : Colors.black54),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _preferredTime != null
                        ? 'At ${_preferredTime!.format(context)}'
                        : 'Default: 9:00 AM',
                    style: TextStyle(
                      fontSize: 13,
                      color: dark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
                if (_preferredTime != null)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _preferredTime = null);
                      _save();
                    },
                    child: Icon(Icons.close_rounded, size: 18, color: dark ? Colors.white38 : Colors.black38),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Hub link — opens the Finance module detail in the Hub
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildHubLink(bool dark) {
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const HubModuleDetailPage(
              moduleId: NotificationHubModuleIds.finance,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_gold.withOpacity(0.12), _gold.withOpacity(0.04)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _gold.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.tune_rounded, size: 18, color: _gold),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manage in Notification Hub',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _gold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sound, channel, vibration & delivery config',
                    style: TextStyle(
                      fontSize: 11,
                      color: dark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _gold),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Helpers
  // ───────────────────────────────────────────────────────────────────────────

  Widget _sectionHeader(IconData icon, String text, bool dark) {
    return Row(
      children: [
        Icon(icon, size: 18, color: dark ? Colors.white70 : Colors.black54),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: dark ? Colors.white70 : Colors.black54,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _preferredTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          timePickerTheme: TimePickerThemeData(
            backgroundColor: widget.isDark ? const Color(0xFF1A1D23) : Colors.white,
            dialBackgroundColor:
                (widget.isDark ? Colors.white : Colors.black).withOpacity(0.04),
          ),
        ),
        child: child!,
      ),
    );
    if (time != null) {
      HapticFeedback.lightImpact();
      setState(() => _preferredTime = time);
      _save();
    }
  }
}

/// Internal helper for type choices.
class _TypeOption {
  final String id;
  final String name;
  final String desc;
  final IconData icon;
  const _TypeOption({
    required this.id,
    required this.name,
    required this.desc,
    required this.icon,
  });
}
