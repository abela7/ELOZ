import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/notifications.dart';
import '../../../../core/providers/notification_settings_provider.dart';
import '../../../../core/theme/color_schemes.dart';
import '../../../../core/widgets/settings_widgets.dart';

/// Quiet hours configuration page.
///
/// Uses [notificationSettingsProvider] so changes propagate to
/// [NotificationService] and all hub modules immediately.
class HubQuietHoursPage extends ConsumerStatefulWidget {
  const HubQuietHoursPage({super.key});

  @override
  ConsumerState<HubQuietHoursPage> createState() => _HubQuietHoursPageState();
}

class _HubQuietHoursPageState extends ConsumerState<HubQuietHoursPage> {
  final _hub = NotificationHub();
  List<NotificationHubModule> _modules = [];
  Map<String, bool> _moduleExceptions = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadModuleExceptions();
  }

  Future<void> _loadModuleExceptions() async {
    await _hub.initialize();
    _modules = _hub.getRegisteredModules();

    for (final m in _modules) {
      final ms = await _hub.getModuleSettings(m.moduleId);
      _moduleExceptions[m.moduleId] = ms.allowDuringQuietHours ?? false;
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _setModuleException(String moduleId, bool allow) async {
    final current = await _hub.getModuleSettings(moduleId);
    await _hub.setModuleSettings(
      moduleId,
      current.copyWith(allowDuringQuietHours: allow),
    );
    if (mounted) setState(() => _moduleExceptions[moduleId] = allow);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    if (_loading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [
        // ── Master toggle ──
        SettingsSection(
          title: 'GENERAL',
          icon: Icons.tune_rounded,
          child: Column(
            children: [
              SettingsToggle(
                title: 'Quiet Hours',
                subtitle: 'Suppress notifications during set hours',
                value: settings.quietHoursEnabled,
                icon: Icons.nightlight_rounded,
                color: Colors.indigo,
                onChanged: (v) => notifier.setQuietHoursEnabled(v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerLow
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.policy_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Quiet-hours rule: notifications are forced silent unless the '
                  'module is allowed here OR the notification type is marked '
                  '"Bypass Quiet Hours".',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Schedule ──
        if (settings.quietHoursEnabled) ...[
          SettingsSection(
            title: 'SCHEDULE',
            icon: Icons.schedule_rounded,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _TimelineVisual(
                    startMinutes: settings.quietHoursStart,
                    endMinutes: settings.quietHoursEnd,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _TimePick(
                          label: 'Start',
                          minutes: settings.quietHoursStart,
                          onChanged: (m) =>
                              notifier.setQuietHoursStart(m),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _TimePick(
                          label: 'End',
                          minutes: settings.quietHoursEnd,
                          onChanged: (m) =>
                              notifier.setQuietHoursEnd(m),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Active Days',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _DaySelector(
                    selectedDays: settings.quietHoursDays,
                    onChanged: (days) =>
                        notifier.setQuietHoursDays(days),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Per-module exceptions ──
          SettingsSection(
            title: 'EXCEPTIONS',
            icon: Icons.rule_rounded,
            child: Column(
              children: [
                ..._modules.asMap().entries.map((entry) {
                  final index = entry.key;
                  final m = entry.value;
                  final allowed = _moduleExceptions[m.moduleId] ?? false;
                  return Column(
                    children: [
                      if (index > 0) _buildDivider(isDark),
                      SettingsToggle(
                        title: m.displayName,
                        subtitle: allowed ? 'Can notify during quiet hours' : 'Silenced',
                        value: allowed,
                        icon: IconData(
                          m.iconCodePoint,
                          fontFamily: m.iconFontFamily,
                          fontPackage: m.iconFontPackage,
                        ),
                        color: Color(m.colorValue),
                        onChanged: (v) => _setModuleException(m.moduleId, v),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 56,
      color: AppColorSchemes.textSecondary.withOpacity(isDark ? 0.2 : 0.1),
    );
  }
}

// ─── Visual timeline ───────────────────────────────────────────────────────

class _TimelineVisual extends StatelessWidget {
  final int startMinutes;
  final int endMinutes;

  const _TimelineVisual(
      {required this.startMinutes, required this.endMinutes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final startFrac = startMinutes / 1440;
    final endFrac = endMinutes / 1440;

    return Column(
      children: [
        SizedBox(
          height: 48,
          child: CustomPaint(
            size: const Size(double.infinity, 48),
            painter: _TimelinePainter(
              startFrac: startFrac,
              endFrac: endFrac,
              quietColor: theme.colorScheme.primary.withOpacity(0.3),
              bgColor: theme.colorScheme.surfaceContainerHighest,
              textColor: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('00:00', style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
            Text('06:00', style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
            Text('12:00', style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
            Text('18:00', style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
            Text('24:00', style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final double startFrac;
  final double endFrac;
  final Color quietColor;
  final Color bgColor;
  final Color textColor;

  _TimelinePainter({
    required this.startFrac,
    required this.endFrac,
    required this.quietColor,
    required this.bgColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = bgColor;
    final quietPaint = Paint()..color = quietColor;
    final radius = size.height / 2;

    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ),
      bgPaint,
    );

    // Quiet range
    if (startFrac < endFrac) {
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * startFrac,
          0,
          size.width * (endFrac - startFrac),
          size.height,
        ),
        quietPaint,
      );
    } else {
      // Wraps around midnight
      canvas.drawRect(
        Rect.fromLTWH(size.width * startFrac, 0,
            size.width * (1 - startFrac), size.height),
        quietPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width * endFrac, size.height),
        quietPaint,
      );
    }

    // Moon icon at center of quiet range
    final textPainter = TextPainter(
      text: TextSpan(
        text: '🌙',
        style: const TextStyle(fontSize: 18),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    double centerFrac;
    if (startFrac < endFrac) {
      centerFrac = (startFrac + endFrac) / 2;
    } else {
      centerFrac = ((startFrac + endFrac + 1) / 2) % 1;
    }

    textPainter.paint(
      canvas,
      Offset(
        (size.width * centerFrac) - textPainter.width / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) =>
      old.startFrac != startFrac || old.endFrac != endFrac;
}

// ─── Time picker ───────────────────────────────────────────────────────────

class _TimePick extends StatelessWidget {
  final String label;
  final int minutes;
  final ValueChanged<int> onChanged;

  const _TimePick(
      {required this.label, required this.minutes, required this.onChanged});

  String _fmt(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
        );
        if (picked != null) {
          onChanged(picked.hour * 60 + picked.minute);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(
              _fmt(minutes),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Day selector ──────────────────────────────────────────────────────────

class _DaySelector extends StatelessWidget {
  final List<int> selectedDays;
  final ValueChanged<List<int>> onChanged;

  const _DaySelector(
      {required this.selectedDays, required this.onChanged});

  static const _labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final dayNum = i + 1; // 1 = Mon, 7 = Sun
        final selected = selectedDays.contains(dayNum);
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            final updated = List<int>.from(selectedDays);
            selected ? updated.remove(dayNum) : updated.add(dayNum);
            updated.sort();
            onChanged(updated);
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _labels[i],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }),
    );
  }
}