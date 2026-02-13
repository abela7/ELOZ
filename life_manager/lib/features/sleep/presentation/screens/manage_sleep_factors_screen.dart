import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/widgets/icon_picker_widget.dart';
import '../../../../core/widgets/color_picker_widget.dart';
import '../../data/models/sleep_factor.dart';
import '../providers/sleep_providers.dart';

/// Manage Pre-Sleep Factors Screen
class ManageSleepFactorsScreen extends ConsumerStatefulWidget {
  const ManageSleepFactorsScreen({super.key});

  @override
  ConsumerState<ManageSleepFactorsScreen> createState() => _ManageSleepFactorsScreenState();
}

class _ManageSleepFactorsScreenState extends ConsumerState<ManageSleepFactorsScreen> {
  bool _goodExpanded = false;
  bool _badExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final factorsAsync = ref.watch(sleepFactorsStreamProvider);

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(child: _buildContent(context, isDark, factorsAsync))
          : _buildContent(context, isDark, factorsAsync),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFactorForm(context, isDark),
        backgroundColor: const Color(0xFFCDAF56),
        foregroundColor: const Color(0xFF1E1E1E),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Factor', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, AsyncValue<List<SleepFactor>> factorsAsync) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Pre-Sleep Factors'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: factorsAsync.when(
        data: (factors) {
          if (factors.isEmpty) {
            return _buildEmptyState(context, isDark);
          }

          final goodFactors = factors.where((factor) => factor.isGood).toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          final badFactors = factors.where((factor) => factor.isBad).toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
            children: [
              _buildInfoBanner(isDark),
              const SizedBox(height: 20),
              _buildAccordionSection(
                context: context,
                isDark: isDark,
                title: 'Good Factors (Boost Sleep)',
                subtitle: '${goodFactors.length} factors',
                icon: Icons.thumb_up_alt_rounded,
                accent: const Color(0xFF4CAF50),
                expanded: _goodExpanded,
                onToggle: () => setState(() => _goodExpanded = !_goodExpanded),
                factors: goodFactors,
              ),
              const SizedBox(height: 12),
              _buildAccordionSection(
                context: context,
                isDark: isDark,
                title: 'Bad Factors (Hurt Sleep)',
                subtitle: '${badFactors.length} factors',
                icon: Icons.warning_amber_rounded,
                accent: const Color(0xFFEF5350),
                expanded: _badExpanded,
                onToggle: () => setState(() => _badExpanded = !_badExpanded),
                factors: badFactors,
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildInfoBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFCDAF56).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCDAF56).withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFCDAF56), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Classify factors as good or bad. The log form will show both groups in an accordion so selection stays clean and fast.',
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccordionSection({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required bool expanded,
    required VoidCallback onToggle,
    required List<SleepFactor> factors,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.35), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.28 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20), bottom: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 180),
                    turns: expanded ? 0.5 : 0,
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: accent),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: factors.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'No factors yet in this group.',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                    )
                  : Column(
                      children: factors
                          .map((factor) => _buildFactorCard(context, isDark, factor))
                          .toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorCard(BuildContext context, bool isDark, SleepFactor factor) {
    final typeAccent = factor.isGood ? const Color(0xFF4CAF50) : const Color(0xFFEF5350);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF22262E) : const Color(0xFFFDFDFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: factor.color.withOpacity(0.35), width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showFactorForm(context, isDark, factor: factor),
          onLongPress: factor.isDefault ? null : () => _confirmDelete(context, isDark, factor),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: factor.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(factor.icon, color: factor.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              factor.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                              ),
                            ),
                          ),
                          _buildPill(
                            label: factor.isGood ? 'GOOD' : 'BAD',
                            color: typeAccent,
                          ),
                          if (factor.isDefault) ...[
                            const SizedBox(width: 6),
                            _buildPill(label: 'DEFAULT', color: const Color(0xFFCDAF56)),
                          ],
                        ],
                      ),
                      if (factor.description != null && factor.description!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          factor.description!,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 15, color: isDark ? Colors.white30 : Colors.black26),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPill({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFFCDAF56).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.psychology_rounded, size: 64, color: const Color(0xFFCDAF56).withOpacity(0.5)),
          ),
          const SizedBox(height: 32),
          Text(
            'No factors yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Add good and bad factors for better sleep insights',
            style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
          ),
        ],
      ),
    );
  }

  void _showFactorForm(BuildContext context, bool isDark, {SleepFactor? factor}) {
    final nameController = TextEditingController(text: factor?.name ?? '');
    final descriptionController = TextEditingController(text: factor?.description ?? '');
    IconData selectedIcon = factor?.icon ?? Icons.local_cafe_rounded;
    Color selectedColor = factor?.color ?? const Color(0xFF8D6E63);
    SleepFactorType selectedType = factor?.factorType ?? SleepFactorType.bad;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2228) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  factor == null ? 'New Factor' : 'Edit Factor',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -0.5),
                ),
                const SizedBox(height: 20),
                Text(
                  'FACTOR TYPE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withOpacity(0.25) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTypeOption(
                          label: 'Good Habit',
                          icon: Icons.thumb_up_alt_rounded,
                          selected: selectedType == SleepFactorType.good,
                          color: const Color(0xFF4CAF50),
                          onTap: () => setSheetState(() => selectedType = SleepFactorType.good),
                        ),
                      ),
                      Expanded(
                        child: _buildTypeOption(
                          label: 'Bad Habit',
                          icon: Icons.warning_amber_rounded,
                          selected: selectedType == SleepFactorType.bad,
                          color: const Color(0xFFEF5350),
                          onTap: () => setSheetState(() => selectedType = SleepFactorType.bad),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    labelText: 'FACTOR NAME',
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
                    hintText: 'e.g., Caffeine, Meditation',
                    filled: true,
                    fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(20),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 2,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    labelText: 'DESCRIPTION (OPTIONAL)',
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
                    hintText: 'Brief description...',
                    filled: true,
                    fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(20),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'ICON & COLOR',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          final icon = await showDialog<IconData>(
                            context: context,
                            builder: (context) => IconPickerWidget(
                              selectedIcon: selectedIcon,
                              isDark: isDark,
                            ),
                          );
                          if (icon != null) {
                            setSheetState(() => selectedIcon = icon);
                          }
                        },
                        child: Container(
                          height: 84,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black.withOpacity(0.35) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: selectedColor.withOpacity(0.7), width: 2),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Icon(
                                  selectedIcon,
                                  size: 38,
                                  color: selectedColor,
                                ),
                              ),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: selectedColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.edit_rounded,
                                    size: 12,
                                    color: selectedColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          final color = await showDialog<Color>(
                            context: context,
                            builder: (context) => ColorPickerWidget(
                              selectedColor: selectedColor,
                              isDark: isDark,
                            ),
                          );
                          if (color != null) {
                            setSheetState(() => selectedColor = color);
                          }
                        },
                        child: Container(
                          height: 84,
                          decoration: BoxDecoration(
                            color: selectedColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark ? Colors.white24 : Colors.black12,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: selectedColor.withOpacity(0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.palette_rounded,
                            size: 34,
                            color: selectedColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a factor name')),
                        );
                        return;
                      }

                      HapticFeedback.heavyImpact();
                      final newFactor = (factor ??
                              SleepFactor(
                                name: nameController.text.trim(),
                                iconCodePoint: selectedIcon.codePoint,
                                colorValue: selectedColor.value,
                                factorTypeValue: selectedType.name,
                              ))
                          .copyWith(
                        name: nameController.text.trim(),
                        description: descriptionController.text.trim().isEmpty
                            ? null
                            : descriptionController.text.trim(),
                        iconCodePoint: selectedIcon.codePoint,
                        colorValue: selectedColor.value,
                        factorTypeValue: selectedType.name,
                        schemaVersion: SleepFactor.currentSchemaVersion,
                      );

                      if (factor == null) {
                        await ref.read(sleepFactorRepositoryProvider).create(newFactor);
                      } else {
                        await ref.read(sleepFactorRepositoryProvider).update(newFactor);
                      }

                      if (context.mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCDAF56),
                      foregroundColor: const Color(0xFF1E1E1E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: Text(
                      factor == null ? 'ADD FACTOR' : 'UPDATE FACTOR',
                      style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 16),
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

  Widget _buildTypeOption({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : Colors.transparent, width: 1.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: selected ? color : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, bool isDark, SleepFactor factor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Factor?'),
        content: Text('Are you sure you want to delete "${factor.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(sleepFactorRepositoryProvider).delete(factor.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
