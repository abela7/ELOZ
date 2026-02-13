import 'package:flutter/material.dart';

import '../../../../core/notifications/models/hub_module_notification_settings.dart';
import '../../../../core/notifications/notification_hub.dart';

/// Module-specific template placeholder definitions.
class _ModulePlaceholders {
  static const task = <Map<String, String>>[
    {'tag': '{title}', 'label': 'Title', 'icon': 'abc'},
    {'tag': '{category}', 'label': 'Category', 'icon': 'category'},
    {'tag': '{description}', 'label': 'Description', 'icon': 'notes'},
    {'tag': '{subtasks}', 'label': 'Subtasks', 'icon': 'checklist'},
    {'tag': '{due_time}', 'label': 'Due time', 'icon': 'schedule'},
    {'tag': '{progress}', 'label': 'Progress', 'icon': 'trending_up'},
    {'tag': '{priority}', 'label': 'Priority', 'icon': 'low_priority'},
  ];

  static const habit = <Map<String, String>>[
    {'tag': '{title}', 'label': 'Title', 'icon': 'abc'},
    {'tag': '{category}', 'label': 'Category', 'icon': 'category'},
    {'tag': '{description}', 'label': 'Description', 'icon': 'notes'},
    {'tag': '{streak}', 'label': 'Streak', 'icon': 'trending_up'},
    {'tag': '{best_streak}', 'label': 'Best streak', 'icon': 'star'},
    {'tag': '{total}', 'label': 'Total done', 'icon': 'checklist'},
    {'tag': '{time}', 'label': 'Time', 'icon': 'schedule'},
    {'tag': '{frequency}', 'label': 'Frequency', 'icon': 'repeat'},
    {'tag': '{goal}', 'label': 'Goal', 'icon': 'flag'},
    {'tag': '{reminder}', 'label': 'Reminder', 'icon': 'alarm'},
  ];

  static const finance = <Map<String, String>>[
    {'tag': '{title}', 'label': 'Title', 'icon': 'abc'},
    {'tag': '{amount}', 'label': 'Amount', 'icon': 'attach_money'},
    {'tag': '{account}', 'label': 'Account', 'icon': 'account_balance'},
    {'tag': '{due_date}', 'label': 'Due date', 'icon': 'schedule'},
    {'tag': '{category}', 'label': 'Category', 'icon': 'category'},
    {'tag': '{note}', 'label': 'Note', 'icon': 'notes'},
  ];

  /// Generic placeholders for modules without a specific set.
  static const generic = <Map<String, String>>[
    {'tag': '{title}', 'label': 'Title', 'icon': 'abc'},
    {'tag': '{description}', 'label': 'Description', 'icon': 'notes'},
    {'tag': '{time}', 'label': 'Time', 'icon': 'schedule'},
    {'tag': '{category}', 'label': 'Category', 'icon': 'category'},
  ];

  static List<Map<String, String>> forModule(String moduleId) {
    switch (moduleId) {
      case 'task':
        return task;
      case 'habit':
        return habit;
      case 'finance':
        return finance;
      default:
        return generic;
    }
  }

  static Map<String, String> sampleDataForModule(String moduleId) {
    switch (moduleId) {
      case 'task':
        return {
          '{title}': 'Buy Groceries',
          '{category}': 'Shopping',
          '{description}': 'Milk, Eggs, Bread',
          '{due_time}': '18:30',
          '{priority}': 'High',
          '{progress}': '2/5',
          '{subtasks}': '• Milk\n• Eggs\n• Bread',
        };
      case 'habit':
        return {
          '{title}': 'Drink Water',
          '{category}': 'Health',
          '{description}': 'Stay hydrated today',
          '{streak}': '7',
          '{best_streak}': '21',
          '{total}': '120',
          '{time}': '09:00',
          '{frequency}': 'Daily',
          '{goal}': '8 glasses',
          '{reminder}': '15 minutes before',
        };
      case 'finance':
        return {
          '{title}': 'Electricity Bill',
          '{amount}': '\$85.00',
          '{account}': 'Main Account',
          '{due_date}': 'Feb 15, 2026',
          '{category}': 'Utilities',
          '{note}': 'Monthly payment',
        };
      default:
        return {
          '{title}': 'Reminder',
          '{description}': 'Check this out',
          '{time}': '10:00',
          '{category}': 'General',
        };
    }
  }
}

/// Unified notification template designer for any module in the Notification
/// Hub.
///
/// Shows a bottom-sheet with two tabs (Normal / Special) where the user can
/// compose notification title & body templates using module-specific
/// placeholder chips. A live preview updates as they type.
class HubTemplateDesigner extends StatefulWidget {
  final String moduleId;
  final HubModuleNotificationSettings currentSettings;
  final ValueChanged<HubModuleNotificationSettings> onSave;

  const HubTemplateDesigner({
    super.key,
    required this.moduleId,
    required this.currentSettings,
    required this.onSave,
  });

  /// Show the template designer as a modal bottom sheet.
  static Future<HubModuleNotificationSettings?> show(
    BuildContext context, {
    required String moduleId,
    required HubModuleNotificationSettings currentSettings,
  }) async {
    return showModalBottomSheet<HubModuleNotificationSettings>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HubTemplateDesignerSheet(
        moduleId: moduleId,
        currentSettings: currentSettings,
      ),
    );
  }

  @override
  State<HubTemplateDesigner> createState() => _HubTemplateDesignerState();
}

class _HubTemplateDesignerState extends State<HubTemplateDesigner> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ---------------------------------------------------------------------------
// Sheet
// ---------------------------------------------------------------------------

class _HubTemplateDesignerSheet extends StatefulWidget {
  final String moduleId;
  final HubModuleNotificationSettings currentSettings;

  const _HubTemplateDesignerSheet({
    required this.moduleId,
    required this.currentSettings,
  });

  @override
  State<_HubTemplateDesignerSheet> createState() =>
      _HubTemplateDesignerSheetState();
}

class _HubTemplateDesignerSheetState extends State<_HubTemplateDesignerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  late final TextEditingController _normalTitleCtl;
  late final TextEditingController _normalBodyCtl;
  late final TextEditingController _specialTitleCtl;
  late final TextEditingController _specialBodyCtl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final s = widget.currentSettings;
    _normalTitleCtl = TextEditingController(text: s.titleTemplate ?? '');
    _normalBodyCtl = TextEditingController(text: s.bodyTemplate ?? '');
    _specialTitleCtl =
        TextEditingController(text: s.specialTitleTemplate ?? '');
    _specialBodyCtl = TextEditingController(text: s.specialBodyTemplate ?? '');

    for (final c in [
      _normalTitleCtl,
      _normalBodyCtl,
      _specialTitleCtl,
      _specialBodyCtl,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _normalTitleCtl.dispose();
    _normalBodyCtl.dispose();
    _specialTitleCtl.dispose();
    _specialBodyCtl.dispose();
    super.dispose();
  }

  void _insertPlaceholder(
    TextEditingController controller,
    String placeholder,
  ) {
    final text = controller.text;
    final selection = controller.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      placeholder,
    );
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + placeholder.length,
      ),
    );
  }

  String _renderPreview(String template, bool isSpecial) {
    if (template.trim().isEmpty) {
      return isSpecial ? 'Special notification preview' : 'Notification preview';
    }
    final sampleData = _ModulePlaceholders.sampleDataForModule(widget.moduleId);
    var result = template;
    sampleData.forEach((key, value) {
      result = result.replaceAll(key, value);
    });
    // Clean up empty lines / dangling bullets
    result = result
        .replaceAll(RegExp(r'•\s*\n'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return result.isEmpty
        ? (isSpecial ? 'Special notification preview' : 'Notification preview')
        : result;
  }

  void _save() {
    final updated = widget.currentSettings.copyWith(
      titleTemplate: _normalTitleCtl.text,
      bodyTemplate: _normalBodyCtl.text,
      specialTitleTemplate: _specialTitleCtl.text,
      specialBodyTemplate: _specialBodyCtl.text,
    );
    Navigator.of(context).pop(updated);
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moduleName =
        NotificationHub().moduleDisplayName(widget.moduleId);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notification Designer',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Customize $moduleName notification templates',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: theme.colorScheme.primary,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: theme.colorScheme.onPrimary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              tabs: [
                Tab(text: 'Normal $moduleName'),
                Tab(text: 'Special $moduleName'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEditor(isSpecial: false),
                _buildEditor(isSpecial: true),
              ],
            ),
          ),
          // Save
          Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + bottomInset),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save Templates'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor({required bool isSpecial}) {
    final theme = Theme.of(context);
    final placeholders = _ModulePlaceholders.forModule(widget.moduleId);
    final titleCtl = isSpecial ? _specialTitleCtl : _normalTitleCtl;
    final bodyCtl = isSpecial ? _specialBodyCtl : _normalBodyCtl;

    final previewTitle = _renderPreview(titleCtl.text, isSpecial);
    final previewBody = _renderPreview(bodyCtl.text, isSpecial);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Preview card
        _buildNotificationPreview(isSpecial, previewTitle, previewBody),
        const SizedBox(height: 16),
        // Title field
        _buildTextField(titleCtl, 'Title template', maxLines: 1),
        const SizedBox(height: 10),
        // Body field
        _buildTextField(bodyCtl, 'Body template', maxLines: 3),
        const SizedBox(height: 10),
        // Placeholder chips
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: placeholders
              .map((p) => _buildPlaceholderChip(p, titleCtl, bodyCtl))
              .toList(),
        ),
        const SizedBox(height: 16),
        // Hint
        Text(
          'Tap a chip to insert it at the cursor position in the focused field.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationPreview(
    bool isSpecial,
    String title,
    String body,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isSpecial ? Icons.star_rounded : Icons.notifications_active_rounded,
            color: isSpecial
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderChip(
    Map<String, String> p,
    TextEditingController titleCtl,
    TextEditingController bodyCtl,
  ) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: Icon(
        _getIconData(p['icon'] ?? 'label'),
        size: 16,
        color: theme.colorScheme.primary,
      ),
      label: Text(
        p['label'] ?? '',
        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
      ),
      backgroundColor:
          theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      side: BorderSide.none,
      onPressed: () {
        // Insert into whichever field currently has focus, or body by default
        final focused = titleCtl.selection.isValid &&
                FocusScope.of(context)
                    .focusedChild
                    ?.context
                    ?.widget
                    .toString()
                    .contains('Title')
            == true;
        _insertPlaceholder(
          focused ? titleCtl : bodyCtl,
          p['tag'] ?? '',
        );
      },
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  IconData _getIconData(String icon) {
    switch (icon) {
      case 'abc':
        return Icons.abc;
      case 'category':
        return Icons.category_outlined;
      case 'notes':
        return Icons.notes_outlined;
      case 'checklist':
        return Icons.checklist_rounded;
      case 'schedule':
        return Icons.schedule_outlined;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'low_priority':
        return Icons.low_priority_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'repeat':
        return Icons.repeat_rounded;
      case 'flag':
        return Icons.flag_rounded;
      case 'alarm':
        return Icons.alarm_rounded;
      case 'attach_money':
        return Icons.attach_money_rounded;
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'title':
        return Icons.title_rounded;
      default:
        return Icons.label_outlined;
    }
  }
}
