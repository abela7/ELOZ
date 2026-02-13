import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/color_schemes.dart';
import '../../providers/habit_notification_settings_provider.dart';

class HabitTemplateBuilder extends ConsumerStatefulWidget {
  const HabitTemplateBuilder({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const HabitTemplateBuilder(),
    );
  }

  @override
  ConsumerState<HabitTemplateBuilder> createState() => _HabitTemplateBuilderState();
}

class _HabitTemplateBuilderState extends ConsumerState<HabitTemplateBuilder>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _normalTitleController;
  late TextEditingController _normalBodyController;
  late TextEditingController _specialTitleController;
  late TextEditingController _specialBodyController;

  final List<Map<String, String>> placeholders = [
    {'tag': '{title}', 'label': 'Title', 'icon': 'title'},
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final settings = ref.read(habitNotificationSettingsProvider);
    _normalTitleController = TextEditingController(text: settings.habitTitleTemplate);
    _normalBodyController = TextEditingController(text: settings.habitBodyTemplate);
    _specialTitleController = TextEditingController(text: settings.specialHabitTitleTemplate);
    _specialBodyController = TextEditingController(text: settings.specialHabitBodyTemplate);

    _normalTitleController.addListener(() => setState(() {}));
    _normalBodyController.addListener(() => setState(() {}));
    _specialTitleController.addListener(() => setState(() {}));
    _specialBodyController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _normalTitleController.dispose();
    _normalBodyController.dispose();
    _specialTitleController.dispose();
    _specialBodyController.dispose();
    super.dispose();
  }

  void _insertPlaceholder(TextEditingController controller, String placeholder) {
    final selection = controller.selection;
    final text = controller.text;
    final newText = text.replaceRange(
      selection.start >= 0 ? selection.start : text.length,
      selection.end >= 0 ? selection.end : text.length,
      placeholder,
    );
    controller.text = newText;
    controller.selection = TextSelection.collapsed(
      offset: (selection.start >= 0 ? selection.start : text.length) + placeholder.length,
    );
  }

  String _renderPreview(String template, bool isSpecial) {
    String rendered = template;
    rendered = rendered.replaceAll('{title}', 'Drink Water');
    rendered = rendered.replaceAll('{category}', 'Health');
    rendered = rendered.replaceAll('{description}', 'Stay hydrated today');
    rendered = rendered.replaceAll('{streak}', '7');
    rendered = rendered.replaceAll('{best_streak}', '21');
    rendered = rendered.replaceAll('{total}', '120');
    rendered = rendered.replaceAll('{time}', '09:00');
    rendered = rendered.replaceAll('{frequency}', 'Daily');
    rendered = rendered.replaceAll('{goal}', '8 glasses');
    rendered = rendered.replaceAll('{reminder}', '15 minutes before');

    rendered = rendered.replaceAll(RegExp(r'\n\s*\n+'), '\n');
    rendered = rendered.trim();
    if (rendered.startsWith('• ')) rendered = rendered.substring(2);
    if (rendered.endsWith(' •')) rendered = rendered.substring(0, rendered.length - 2);

    if (rendered.isEmpty) {
      return isSpecial ? '⭐ Special Habit' : 'Habit Reminder';
    }
    return rendered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final surfaceColor = theme.colorScheme.surface;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notification Designer',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Customize habit reminder templates',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            indicatorColor: AppColorSchemes.primaryGold,
            labelColor: AppColorSchemes.primaryGold,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            tabs: const [
              Tab(text: 'Normal Habit'),
              Tab(text: 'Special Habit'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTemplateEditor(false),
                _buildTemplateEditor(true),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomInset),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  final notifier = ref.read(habitNotificationSettingsProvider.notifier);
                  await notifier.setHabitTitleTemplate(_normalTitleController.text);
                  await notifier.setHabitBodyTemplate(_normalBodyController.text);
                  await notifier.setSpecialHabitTitleTemplate(_specialTitleController.text);
                  await notifier.setSpecialHabitBodyTemplate(_specialBodyController.text);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Templates saved successfully'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColorSchemes.primaryGold,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text(
                  'Save Template',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateEditor(bool isSpecial) {
    final titleController = isSpecial ? _specialTitleController : _normalTitleController;
    final bodyController = isSpecial ? _specialBodyController : _normalBodyController;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LIVE PREVIEW',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _buildNotificationPreview(isSpecial, titleController.text, bodyController.text),
          const SizedBox(height: 24),
          Text(
            'AVAILABLE PLACEHOLDERS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: placeholders
                .map((p) => _buildPlaceholderChip(p, titleController, bodyController))
                .toList(),
          ),
          const SizedBox(height: 24),
          Text(
            'SUBJECT TEMPLATE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField(titleController, 'Subject (e.g. {title})'),
          const SizedBox(height: 20),
          Text(
            'DETAIL TEMPLATE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField(bodyController, 'Detail (e.g. {streak} • {time})', maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildNotificationPreview(bool isSpecial, String title, String body) {
    final theme = Theme.of(context);
    final iconColor = isSpecial ? theme.colorScheme.error : AppColorSchemes.primaryGold;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isSpecial ? Icons.star_rounded : Icons.notifications_active_rounded,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _renderPreview(title, isSpecial),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _renderPreview(body, isSpecial),
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderChip(
    Map<String, String> p,
    TextEditingController title,
    TextEditingController body,
  ) {
    final theme = Theme.of(context);
    return ActionChip(
      onPressed: () {
        if (title.selection.start >= 0) {
          _insertPlaceholder(title, p['tag']!);
        } else {
          _insertPlaceholder(body, p['tag']!);
        }
      },
      avatar: Icon(_getIconData(p['icon']!), size: 14, color: AppColorSchemes.primaryGold),
      label: Text(p['label']!),
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  IconData _getIconData(String icon) {
    switch (icon) {
      case 'title':
        return Icons.abc_rounded;
      case 'category':
        return Icons.category_rounded;
      case 'notes':
        return Icons.notes_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'checklist':
        return Icons.checklist_rounded;
      case 'schedule':
        return Icons.schedule_rounded;
      case 'repeat':
        return Icons.repeat_rounded;
      case 'flag':
        return Icons.flag_rounded;
      case 'alarm':
        return Icons.alarm_rounded;
      default:
        return Icons.add;
    }
  }
}
