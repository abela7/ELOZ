import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/notification_settings_provider.dart';
import '../../../../core/models/notification_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/notification_settings_provider.dart';
import '../../../../core/models/notification_settings.dart';
import '../../../../core/theme/color_schemes.dart';

class NotificationTemplateBuilder extends ConsumerStatefulWidget {
  const NotificationTemplateBuilder({super.key});

  @override
  ConsumerState<NotificationTemplateBuilder> createState() => _NotificationTemplateBuilderState();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotificationTemplateBuilder(),
    );
  }
}

class _NotificationTemplateBuilderState extends ConsumerState<NotificationTemplateBuilder> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _normalTitleController;
  late TextEditingController _normalBodyController;
  late TextEditingController _specialTitleController;
  late TextEditingController _specialBodyController;

  final List<Map<String, String>> placeholders = [
    {'tag': '{title}', 'label': 'Title', 'icon': 'abc'},
    {'tag': '{category}', 'label': 'Category', 'icon': 'category'},
    {'tag': '{description}', 'label': 'Description', 'icon': 'notes'},
    {'tag': '{subtasks}', 'label': 'Subtasks', 'icon': 'checklist'},
    {'tag': '{due_time}', 'label': 'Due time', 'icon': 'schedule'},
    {'tag': '{progress}', 'label': 'Progress', 'icon': 'trending_up'},
    {'tag': '{priority}', 'label': 'Priority', 'icon': 'low_priority'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    final settings = ref.read(notificationSettingsProvider);
    _normalTitleController = TextEditingController(text: settings.taskTitleTemplate);
    _normalBodyController = TextEditingController(text: settings.taskBodyTemplate);
    _specialTitleController = TextEditingController(text: settings.specialTaskTitleTemplate);
    _specialBodyController = TextEditingController(text: settings.specialTaskBodyTemplate);

    // Update state when typing
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
    rendered = rendered.replaceAll('{title}', 'Buy Groceries');
    rendered = rendered.replaceAll('{category}', 'Shopping');
    rendered = rendered.replaceAll('{description}', 'Milk, Eggs, Bread');
    rendered = rendered.replaceAll('{due_time}', '18:30');
    rendered = rendered.replaceAll('{priority}', 'High');
    rendered = rendered.replaceAll('{progress}', '2/5');
    rendered = rendered.replaceAll('{subtasks}', '• Milk\n• Eggs\n• Bread');
    
    // Clean up
    rendered = rendered.replaceAll(' •  • ', ' • ');
    // Remove empty lines introduced by missing placeholders
    rendered = rendered.replaceAll(RegExp(r'\n\s*\n+'), '\n');
    rendered = rendered.trim();
    if (rendered.startsWith('• ')) rendered = rendered.substring(2);
    if (rendered.endsWith(' •')) rendered = rendered.substring(0, rendered.length - 2);
    
    return rendered.isEmpty ? (isSpecial ? '⭐ Task Title' : 'Task Title') : rendered;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
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
                      'Customize your alert templates',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : AppColorSchemes.textSecondary,
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

          // Tabs
          TabBar(
            controller: _tabController,
            indicatorColor: AppColorSchemes.primaryGold,
            labelColor: AppColorSchemes.primaryGold,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Normal Task'),
              Tab(text: 'Special Task'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTemplateEditor(isDark, false),
                _buildTemplateEditor(isDark, true),
              ],
            ),
          ),

          // Save Button
          Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomInset),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  final notifier = ref.read(notificationSettingsProvider.notifier);
                  await notifier.setTaskTitleTemplate(_normalTitleController.text);
                  await notifier.setTaskBodyTemplate(_normalBodyController.text);
                  await notifier.setSpecialTaskTitleTemplate(_specialTitleController.text);
                  await notifier.setSpecialTaskBodyTemplate(_specialBodyController.text);
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Templates saved successfully!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColorSchemes.primaryGold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Save Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateEditor(bool isDark, bool isSpecial) {
    final titleController = isSpecial ? _specialTitleController : _normalTitleController;
    final bodyController = isSpecial ? _specialBodyController : _normalBodyController;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Preview Section
          const Text(
            'LIVE PREVIEW',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          _buildNotificationPreview(isDark, isSpecial, titleController.text, bodyController.text),
          
          const SizedBox(height: 24),

          // Placeholder Chips
          const Text(
            'AVAILABLE PLACEHOLDERS',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: placeholders.map((p) => _buildPlaceholderChip(isDark, p, titleController, bodyController)).toList(),
          ),

          const SizedBox(height: 24),

          // Subject Input
          const Text(
            'SUBJECT TEMPLATE',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          _buildTextField(isDark, titleController, 'Subject (e.g. {title})'),

          const SizedBox(height: 20),

          // Detail Input
          const Text(
            'DETAIL TEMPLATE',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          _buildTextField(isDark, bodyController, 'Detail (e.g. {category} • {due_time})', maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildNotificationPreview(bool isDark, bool isSpecial, String title, String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSpecial ? const Color(0xFFE53935).withOpacity(0.2) : AppColorSchemes.primaryGold.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isSpecial ? Icons.star_rounded : Icons.notifications_active_rounded,
              color: isSpecial ? const Color(0xFFE53935) : AppColorSchemes.primaryGold,
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
                    color: isDark ? Colors.white54 : AppColorSchemes.textSecondary,
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

  Widget _buildPlaceholderChip(bool isDark, Map<String, String> p, TextEditingController title, TextEditingController body) {
    return ActionChip(
      onPressed: () {
        // Find which field is focused, or default to body
        if (title.selection.start >= 0) {
          _insertPlaceholder(title, p['tag']!);
        } else {
          _insertPlaceholder(body, p['tag']!);
        }
      },
      avatar: Icon(_getIconData(p['icon']!), size: 14, color: AppColorSchemes.primaryGold),
      label: Text(p['label']!),
      backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildTextField(bool isDark, TextEditingController controller, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
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
      case 'abc': return Icons.abc_rounded;
      case 'category': return Icons.category_rounded;
      case 'schedule': return Icons.schedule_rounded;
      case 'trending_up': return Icons.trending_up_rounded;
      case 'low_priority': return Icons.low_priority_rounded;
      default: return Icons.add;
    }
  }
}
