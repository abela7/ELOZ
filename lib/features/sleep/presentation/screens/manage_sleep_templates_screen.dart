import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/color_schemes.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/sleep_template.dart';
import '../providers/sleep_providers.dart';

class ManageSleepTemplatesScreen extends ConsumerStatefulWidget {
  const ManageSleepTemplatesScreen({super.key});

  @override
  ConsumerState<ManageSleepTemplatesScreen> createState() =>
      _ManageSleepTemplatesScreenState();
}

class _ManageSleepTemplatesScreenState
    extends ConsumerState<ManageSleepTemplatesScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final templatesAsync = ref.watch(sleepTemplatesStreamProvider);

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(
              child: _buildContent(context, isDark, templatesAsync),
            )
          : _buildContent(context, isDark, templatesAsync),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTemplateForm(context, isDark),
        backgroundColor: AppColorSchemes.primaryGold,
        foregroundColor: AppColorSchemes.textPrimary,
        elevation: 2,
        focusElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Template',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    AsyncValue<List<SleepTemplate>> templatesAsync,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor:
          isDark ? Colors.transparent : colorScheme.surfaceContainerHighest,
      appBar: AppBar(
        title: const Text('Sleep Templates'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: templatesAsync.when(
        data: (templates) {
          if (templates.isEmpty) {
            return _buildEmptyState(context, isDark);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColorSchemes.primaryGold.withOpacity(isDark ? 0.12 : 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColorSchemes.primaryGold.withOpacity(isDark ? 0.25 : 0.15),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColorSchemes.primaryGold.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.lightbulb_outline_rounded,
                        color: AppColorSchemes.primaryGold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick tip',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppColorSchemes.primaryGold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Hold a template to set it as default, edit, or delete. The default pre-fills when you add a sleep log.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white.withOpacity(0.85)
                                  : AppColorSchemes.textPrimary.withOpacity(0.85),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Section title
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  'YOUR TEMPLATES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppColorSchemes.primaryGold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              ...templates.map(
                (template) => _buildTemplateCard(context, isDark, template),
              ),
            ],
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(
            color: AppColorSchemes.primaryGold,
          ),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Could not load templates',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateCard(
    BuildContext context,
    bool isDark,
    SleepTemplate template,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = template.isNap
        ? const Color(0xFF9C27B0)
        : const Color(0xFF42A5F5);
    final durationHours = template.durationMinutes ~/ 60;
    final durationMinutes = template.durationMinutes % 60;
    final durationText = durationMinutes == 0
        ? '${durationHours}h'
        : '${durationHours}h ${durationMinutes}m';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerLow : colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? colorScheme.outline.withOpacity(0.15)
              : colorScheme.outline.withOpacity(0.08),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.blackOpacity005,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showTemplateForm(context, isDark, template: template),
          onLongPress: () => _showTemplateActionsSheet(context, isDark, template),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon container with gradient
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withOpacity(isDark ? 0.25 : 0.15),
                        accent.withOpacity(isDark ? 0.15 : 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: accent.withOpacity(isDark ? 0.3 : 0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    template.isNap
                        ? Icons.bolt_rounded
                        : Icons.nightlight_round,
                    color: accent,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child:                           Text(
                            template.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: colorScheme.onSurface,
                            ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (template.isDefault)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColorSchemes.primaryGold.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColorSchemes.primaryGold.withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                'DEFAULT',
                                style: TextStyle(
                                  color: AppColorSchemes.textPrimary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${_formatTime(template.bedHour, template.bedMinute)} – ${_formatTime(template.wakeHour, template.wakeMinute)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(isDark ? 0.15 : 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: accent.withOpacity(isDark ? 0.3 : 0.25),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  template.isNap
                                      ? Icons.bolt_rounded
                                      : Icons.bedtime_rounded,
                                  size: 12,
                                  color: accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  template.isNap ? 'Nap' : 'Night Sleep',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: colorScheme.outline.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              durationText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark
                      ? Colors.white.withOpacity(0.35)
                      : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColorSchemes.primaryGold.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColorSchemes.primaryGold.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.library_books_rounded,
                size: 52,
                color: AppColorSchemes.primaryGold.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No templates yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Create templates for fast sleep logging. Hold a template to set default, edit, or delete.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => _showTemplateForm(context, isDark),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Create your first template'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColorSchemes.primaryGold,
                foregroundColor: AppColorSchemes.textPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTemplateForm(
    BuildContext context,
    bool isDark, {
    SleepTemplate? template,
  }) {
    final nameController = TextEditingController(text: template?.name ?? '');
    TimeOfDay bed = TimeOfDay(
      hour: template?.bedHour ?? 23,
      minute: template?.bedMinute ?? 0,
    );
    TimeOfDay wake = TimeOfDay(
      hour: template?.wakeHour ?? 7,
      minute: template?.wakeMinute ?? 0,
    );
    bool isNap = template?.isNap ?? false;

    Future<void> pickBed() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: bed,
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: const Color(0xFFCDAF56),
                    onPrimary: Colors.black,
                    surface: const Color(0xFF2D3139),
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
                    primary: const Color(0xFFCDAF56),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: const Color(0xFF1E1E1E),
                  ),
          ),
          child: child!,
        ),
      );
      if (picked != null) {
        bed = picked;
      }
    }

    Future<void> pickWake() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: wake,
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: const Color(0xFFCDAF56),
                    onPrimary: Colors.black,
                    surface: const Color(0xFF2D3139),
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
                    primary: const Color(0xFFCDAF56),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: const Color(0xFF1E1E1E),
                  ),
          ),
          child: child!,
        ),
      );
      if (picked != null) {
        wake = picked;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D23) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  template == null ? 'New Sleep Template' : 'Edit Template',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                // Form fields in a styled container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.03)
                        : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Template name field
                      Text(
                        'TEMPLATE NAME',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white38 : Colors.black38,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: nameController,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g., Early Night, Power Nap',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.08),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFCDAF56),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Time pickers
                      Row(
                        children: [
                          Expanded(
                            child: _timeCard(
                              context: context,
                              isDark: isDark,
                              title: 'BED TIME',
                              time: bed.format(context),
                              icon: Icons.nightlight_rounded,
                              onTap: () async {
                                await pickBed();
                                setSheetState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _timeCard(
                              context: context,
                              isDark: isDark,
                              title: 'WAKE TIME',
                              time: wake.format(context),
                              icon: Icons.wb_sunny_rounded,
                              onTap: () async {
                                await pickWake();
                                setSheetState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Sleep type selector
                      Text(
                        'SLEEP TYPE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white38 : Colors.black38,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _typeBtn(
                                label: 'Night Sleep',
                                icon: Icons.nightlight_rounded,
                                selected: !isNap,
                                isDark: isDark,
                                onTap: () => setSheetState(() => isNap = false),
                              ),
                            ),
                            Expanded(
                              child: _typeBtn(
                                label: 'Nap',
                                icon: Icons.bolt_rounded,
                                selected: isNap,
                                isDark: isDark,
                                onTap: () => setSheetState(() => isNap = true),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;
                      HapticFeedback.mediumImpact();

                      final updated =
                          (template ??
                                  SleepTemplate(
                                    name: name,
                                    bedHour: bed.hour,
                                    bedMinute: bed.minute,
                                    wakeHour: wake.hour,
                                    wakeMinute: wake.minute,
                                    isNap: isNap,
                                  ))
                              .copyWith(
                                name: name,
                                bedHour: bed.hour,
                                bedMinute: bed.minute,
                                wakeHour: wake.hour,
                                wakeMinute: wake.minute,
                                isNap: isNap,
                                updatedAt: DateTime.now(),
                              );

                      if (template == null) {
                        await ref
                            .read(sleepTemplateRepositoryProvider)
                            .create(updated);
                      } else {
                        await ref
                            .read(sleepTemplateRepositoryProvider)
                            .update(updated);
                      }

                      if (context.mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCDAF56),
                      foregroundColor: const Color(0xFF1E1E1E),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      template == null ? 'CREATE TEMPLATE' : 'UPDATE TEMPLATE',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeCard({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String time,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white38 : Colors.black38,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(icon, size: 14, color: const Color(0xFFCDAF56)),
                const SizedBox(width: 6),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeBtn({
    required String label,
    required IconData icon,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFCDAF56) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFFCDAF56).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? const Color(0xFF1E1E1E)
                  : (isDark ? Colors.white54 : Colors.black45),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected
                    ? const Color(0xFF1E1E1E)
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTemplateActionsSheet(
    BuildContext context,
    bool isDark,
    SleepTemplate template,
  ) {
    HapticFeedback.mediumImpact();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surfaceContainerHigh : colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outline.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                template.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              _ActionTile(
                icon: template.isDefault
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                label: template.isDefault
                    ? 'Default Template'
                    : 'Make Default',
                color: AppColorSchemes.primaryGold,
                onTap: () async {
                  Navigator.pop(context);
                  await ref
                      .read(sleepTemplateRepositoryProvider)
                      .setAsDefault(template.id);
                },
              ),
              _ActionTile(
                icon: Icons.edit_rounded,
                label: 'Edit',
                color: colorScheme.onSurfaceVariant,
                onTap: () {
                  Navigator.pop(context);
                  _showTemplateForm(context, isDark, template: template);
                },
              ),
              if (!template.isDefault)
                _ActionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  color: AppColors.error,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete(context, isDark, template);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    bool isDark,
    SleepTemplate template,
  ) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Template?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${template.name}"? This action cannot be undone.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(sleepTemplateRepositoryProvider)
                  .delete(template.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final normalized = hour % 12 == 0 ? 12 : hour % 12;
    final mm = minute.toString().padLeft(2, '0');
    return '$normalized:$mm $period';
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 16),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
