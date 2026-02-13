import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/completion_type_config.dart';
import '../../providers/completion_type_config_providers.dart';
import '../../providers/habit_providers.dart';
import '../../services/quit_habit_report_access_guard.dart';
import 'quit_habit_report_security_screen.dart';
import '../../../../../core/widgets/sheet_dismiss_on_overscroll.dart';

/// Habit Completion Types Screen - Manage completion type configurations
class HabitCompletionTypesScreen extends ConsumerWidget {
  const HabitCompletionTypesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final configsAsync = ref.watch(completionTypeConfigNotifierProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: configsAsync.when(
        data: (configs) => _buildContent(context, isDark, configs, ref),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
    ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    List<CompletionTypeConfig> configs,
    WidgetRef ref,
  ) {
    // Find each config by typeId
    final yesNoConfig = configs.firstWhere(
      (c) => c.typeId == 'yesNo',
      orElse: () => CompletionTypeConfig.yesNoDefault(),
    );
    final numericConfig = configs.firstWhere(
      (c) => c.typeId == 'numeric',
      orElse: () => CompletionTypeConfig.numericDefault(),
    );
    final timerConfig = configs.firstWhere(
      (c) => c.typeId == 'timer',
      orElse: () => CompletionTypeConfig.timerDefault(),
    );
    final quitConfig = configs.firstWhere(
      (c) => c.typeId == 'quit',
      orElse: () => CompletionTypeConfig.quitDefault(),
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        Text(
          'Completion Types',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose how you want to track each habit.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),

        // Yes/No Type
        _buildTypeCard(
          context: context,
          isDark: isDark,
          config: yesNoConfig,
          icon: Icons.check_circle_outline,
          iconColor: const Color(0xFF4CAF50),
          description: 'Simple binary tracking: Did you do it? Yes or No.',
          examples: [
            'Did you brush your teeth?',
            'Did you take vitamins?',
            'Did you meditate today?',
          ],
          configInfo: yesNoConfig.isEnabled
              ? 'YES: +${yesNoConfig.defaultYesPoints ?? 0} | NO: ${yesNoConfig.defaultNoPoints ?? 0} | POSTPONE: ${yesNoConfig.defaultPostponePoints ?? 0}'
              : 'Disabled',
          onConfigure: () =>
              _showYesNoConfigSheet(context, isDark, yesNoConfig, ref),
        ),

        // Numeric Type
        _buildTypeCard(
          context: context,
          isDark: isDark,
          config: numericConfig,
          icon: Icons.numbers_rounded,
          iconColor: const Color(0xFF2196F3),
          description: 'Track habits with measurable values and units.',
          examples: [
            'Sleep 8 hours',
            'Drink 2 liters of water',
            'Read 50 pages',
          ],
          configInfo: numericConfig.isEnabled
              ? 'Method: ${_getCalculationMethodName(numericConfig.defaultCalculationMethod)} | Threshold: ${numericConfig.defaultThresholdPercent?.toInt() ?? 80}%'
              : 'Disabled',
          onConfigure: () =>
              _showNumericConfigSheet(context, isDark, numericConfig, ref),
        ),

        // Timer Type
        _buildTypeCard(
          context: context,
          isDark: isDark,
          config: timerConfig,
          icon: Icons.timer_outlined,
          iconColor: const Color(0xFF9C27B0),
          description: 'Track time-based habits with duration goals.',
          examples: [
            'Sleep 8 hours (target)',
            'Study for 4 hours (target)',
            'Pray at least 1 hour (minimum + bonus)',
          ],
          configInfo: timerConfig.isEnabled
              ? 'Type: ${_getTimerTypeName(timerConfig.defaultTimerType)} | Base: +${timerConfig.defaultYesPoints ?? 10} pts'
              : 'Disabled',
          onConfigure: () =>
              _showTimerConfigSheet(context, isDark, timerConfig, ref),
        ),

        // Quit Type
        _buildTypeCard(
          context: context,
          isDark: isDark,
          config: quitConfig,
          icon: Icons.smoke_free_rounded,
          iconColor: Colors.red,
          description:
              'Break bad habits: Track slips, resist temptations, earn rewards for staying clean.',
          examples: [
            'Quit smoking (track cigarettes avoided)',
            'Stop drinking (log slips with reasons)',
            'Resist junk food (temptation tracking)',
          ],
          configInfo: quitConfig.isEnabled
              ? 'Daily: +${quitConfig.defaultDailyReward ?? 10} | Slip: ${quitConfig.defaultSlipPenalty ?? -20}'
              : 'Disabled',
          onConfigure: () =>
              _openSecureQuitConfigSheet(context, isDark, quitConfig, ref),
        ),

        const SizedBox(height: 20),

        // Info Card
        Card(
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.15),
          color: const Color(0xFFCDAF56).withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFCDAF56), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFCDAF56)),
                    const SizedBox(width: 8),
                    Text(
                      'How to Use',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'When creating a habit, you\'ll choose a completion type. '
                  'Tap "Configure" on any type to set default values for new habits. '
                  'All types are now ready to use!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeCard({
    required BuildContext context,
    required bool isDark,
    required CompletionTypeConfig config,
    required IconData icon,
    required Color iconColor,
    required String description,
    required List<String> examples,
    required String configInfo,
    VoidCallback? onConfigure,
  }) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.15),
      color: isDark ? const Color(0xFF2D3139) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Icon and Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        config.isEnabled ? 'Enabled' : 'Disabled',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: config.isEnabled
                              ? const Color(0xFF4CAF50)
                              : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onConfigure != null)
                  IconButton(
                    onPressed: onConfigure,
                    icon: const Icon(Icons.settings_rounded),
                    color: const Color(0xFFCDAF56),
                    tooltip: 'Configure',
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),

            // Examples
            Text(
              'Examples:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            ...examples.map(
              (example) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        example,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Points Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFCDAF56).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events_outlined,
                    color: Color(0xFFCDAF56),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      configInfo,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCalculationMethodName(String? method) {
    switch (method) {
      case 'proportional':
        return 'Proportional';
      case 'threshold':
        return 'Threshold';
      case 'perUnit':
        return 'Per Unit';
      default:
        return 'Proportional';
    }
  }

  String _getTimerTypeName(String? timerType) {
    switch (timerType) {
      case 'minimum':
        return 'Minimum + Bonus';
      case 'target':
      default:
        return 'Target Goal';
    }
  }

  /// Show configuration sheet for Yes/No type
  void _showYesNoConfigSheet(
    BuildContext context,
    bool isDark,
    CompletionTypeConfig config,
    WidgetRef ref,
  ) {
    final yesController = TextEditingController(
      text: config.defaultYesPoints?.toString() ?? '10',
    );
    final noController = TextEditingController(
      text: config.defaultNoPoints?.toString() ?? '-10',
    );
    final postponeController = TextEditingController(
      text: config.defaultPostponePoints?.toString() ?? '-5',
    );

    final successColor = isDark ? Colors.green[400]! : Colors.green[700]!;
    final errorColor = Theme.of(context).colorScheme.error;
    final warningColor = const Color(0xFFCDAF56);
    final accentColor = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SheetDismissOnOverscroll(
        child: Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16),
          child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 10,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D21) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pull Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                Text(
                  'Configure Yes/No',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Default points for simple Yes/No habits.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),

                _buildSectionHeader(context, isDark, 'POINTS SYSTEM'),
                const SizedBox(height: 16),

                _buildModernInputField(
                  context: context,
                  isDark: isDark,
                  label: 'Default YES Points',
                  controller: yesController,
                  prefixText: '+',
                  color: successColor,
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(height: 16),

                _buildModernInputField(
                  context: context,
                  isDark: isDark,
                  label: 'Default NO Points',
                  controller: noController,
                  color: errorColor,
                  icon: Icons.cancel_outlined,
                ),
                const SizedBox(height: 16),

                _buildModernInputField(
                  context: context,
                  isDark: isDark,
                  label: 'Default POSTPONE Points',
                  controller: postponeController,
                  color: warningColor,
                  icon: Icons.pause_circle_outline,
                ),
                const SizedBox(height: 32),

                // Save Button
                Container(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      final yesPoints = int.tryParse(yesController.text) ?? 10;
                      final noPoints = int.tryParse(noController.text) ?? -10;
                      final postponePoints =
                          int.tryParse(postponeController.text) ?? -5;

                      final updatedConfig = config.copyWith(
                        defaultYesPoints: yesPoints,
                        defaultNoPoints: noPoints,
                        defaultPostponePoints: postponePoints,
                      );

                      ref
                          .read(completionTypeConfigNotifierProvider.notifier)
                          .updateConfig(updatedConfig);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Yes/No defaults updated!'),
                          backgroundColor: successColor,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Save Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  /// Show configuration sheet for Numeric type
  void _showNumericConfigSheet(
    BuildContext context,
    bool isDark,
    CompletionTypeConfig config,
    WidgetRef ref,
  ) {
    String selectedMethod = config.defaultCalculationMethod ?? 'proportional';
    final thresholdController = TextEditingController(
      text: (config.defaultThresholdPercent ?? 80).toInt().toString(),
    );
    final fullPointsController = TextEditingController(
      text: config.defaultYesPoints?.toString() ?? '10',
    );
    final noPointsController = TextEditingController(
      text: config.defaultNoPoints?.toString() ?? '-10',
    );
    final postponePointsController = TextEditingController(
      text: config.defaultPostponePoints?.toString() ?? '-5',
    );

    final successColor = isDark ? Colors.green[400]! : Colors.green[700]!;
    final errorColor = Theme.of(context).colorScheme.error;
    final warningColor = const Color(0xFFCDAF56);
    final accentColor = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => SheetDismissOnOverscroll(
          child: Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
            ),
            child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 10,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D21) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pull Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  Text(
                    'Configure Numeric',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'How points are calculated for numeric habits.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionHeader(context, isDark, 'CALCULATION METHOD'),
                  const SizedBox(height: 12),

                  _buildMethodCard(
                    context: context,
                    isDark: isDark,
                    title: 'Proportional',
                    description: 'Points based on % of target reached.',
                    isSelected: selectedMethod == 'proportional',
                    onTap: () =>
                        setState(() => selectedMethod = 'proportional'),
                    color: accentColor,
                  ),
                  const SizedBox(height: 8),
                  _buildMethodCard(
                    context: context,
                    isDark: isDark,
                    title: 'Threshold',
                    description: 'Full points only if threshold reached.',
                    isSelected: selectedMethod == 'threshold',
                    onTap: () => setState(() => selectedMethod = 'threshold'),
                    color: successColor,
                  ),
                  const SizedBox(height: 8),
                  _buildMethodCard(
                    context: context,
                    isDark: isDark,
                    title: 'Per Unit',
                    description: 'Points for each unit completed.',
                    isSelected: selectedMethod == 'perUnit',
                    onTap: () => setState(() => selectedMethod = 'perUnit'),
                    color: warningColor,
                  ),
                  const SizedBox(height: 24),

                  if (selectedMethod == 'threshold') ...[
                    _buildModernInputField(
                      context: context,
                      isDark: isDark,
                      label: 'Threshold Percentage',
                      controller: thresholdController,
                      color: accentColor,
                      icon: Icons.speed,
                      prefixText: '',
                    ),
                    const SizedBox(height: 24),
                  ],

                  _buildSectionHeader(context, isDark, 'POINTS SYSTEM'),
                  const SizedBox(height: 16),

                  _buildModernInputField(
                    context: context,
                    isDark: isDark,
                    label: 'Full Completion Points',
                    controller: fullPointsController,
                    prefixText: '+',
                    color: successColor,
                    icon: Icons.add_circle_outline,
                  ),
                  const SizedBox(height: 16),

                  _buildModernInputField(
                    context: context,
                    isDark: isDark,
                    label: 'No Completion Penalty',
                    controller: noPointsController,
                    color: errorColor,
                    icon: Icons.cancel_outlined,
                  ),
                  const SizedBox(height: 16),

                  _buildModernInputField(
                    context: context,
                    isDark: isDark,
                    label: 'Postpone Penalty',
                    controller: postponePointsController,
                    color: warningColor,
                    icon: Icons.pause_circle_outline,
                  ),
                  const SizedBox(height: 32),

                  // Save Button
                  Container(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        final threshold =
                            double.tryParse(thresholdController.text) ?? 80;
                        final fullPoints =
                            int.tryParse(fullPointsController.text) ?? 10;
                        final noPoints =
                            int.tryParse(noPointsController.text) ?? -10;
                        final postponePoints =
                            int.tryParse(postponePointsController.text) ?? -5;

                        final updatedConfig = config.copyWith(
                          isEnabled: true,
                          defaultCalculationMethod: selectedMethod,
                          defaultThresholdPercent: threshold,
                          defaultYesPoints: fullPoints,
                          defaultNoPoints: noPoints,
                          defaultPostponePoints: postponePoints,
                        );

                        ref
                            .read(completionTypeConfigNotifierProvider.notifier)
                            .updateConfig(updatedConfig);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Numeric defaults updated!'),
                            backgroundColor: successColor,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Save Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  /// Show configuration sheet for Timer type
  void _showTimerConfigSheet(
    BuildContext context,
    bool isDark,
    CompletionTypeConfig config,
    WidgetRef ref,
  ) {
    String selectedTimerType = config.defaultTimerType ?? 'target';
    final basePointsController = TextEditingController(
      text: config.defaultYesPoints?.toString() ?? '10',
    );
    final noPointsController = TextEditingController(
      text: config.defaultNoPoints?.toString() ?? '-10',
    );
    final postponePointsController = TextEditingController(
      text: config.defaultPostponePoints?.toString() ?? '-5',
    );
    final bonusController = TextEditingController(
      text: config.defaultBonusPerMinute?.toString() ?? '0.1',
    );
    bool allowOvertime = config.allowOvertimeBonus ?? true;

    final accentColor = Theme.of(context).colorScheme.primary;
    final successColor = isDark ? Colors.green[400]! : Colors.green[700]!;
    final errorColor = Theme.of(context).colorScheme.error;
    final warningColor = const Color(0xFFCDAF56);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return SheetDismissOnOverscroll(
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
              ),
              child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 10,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D21) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pull Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    Text(
                      'Configure Timer',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'How points are calculated for time habits.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section: Mode
                    _buildSectionHeader(context, isDark, 'TIMER MODE'),
                    const SizedBox(height: 12),
                    _buildTimerTypeCard(
                      context: context,
                      isDark: isDark,
                      title: 'Target Goal',
                      description: 'Proportional points based on % reached.',
                      example: 'Goal 8h → slept 4h = 50% points',
                      isSelected: selectedTimerType == 'target',
                      onTap: () => setState(() => selectedTimerType = 'target'),
                      color: accentColor,
                    ),
                    const SizedBox(height: 8),
                    _buildTimerTypeCard(
                      context: context,
                      isDark: isDark,
                      title: 'Minimum + Bonus',
                      description: 'Full points at minimum, bonus for extra.',
                      example: 'Min 1h → prayed 2h = base + bonus',
                      isSelected: selectedTimerType == 'minimum',
                      onTap: () =>
                          setState(() => selectedTimerType = 'minimum'),
                      color: successColor,
                    ),

                    const SizedBox(height: 32),

                    // Section: Points
                    _buildSectionHeader(context, isDark, 'POINTS SYSTEM'),
                    const SizedBox(height: 16),

                    _buildModernInputField(
                      context: context,
                      isDark: isDark,
                      label: selectedTimerType == 'target'
                          ? 'Full Target Points'
                          : 'Minimum Reached Points',
                      controller: basePointsController,
                      prefixText: '+',
                      color: successColor,
                      icon: Icons.add_circle_outline,
                    ),
                    const SizedBox(height: 16),

                    _buildModernInputField(
                      context: context,
                      isDark: isDark,
                      label: selectedTimerType == 'minimum'
                          ? 'Bonus Per Extra Minute'
                          : 'Overtime Bonus Per Minute',
                      controller: bonusController,
                      prefixText: '+',
                      color: accentColor,
                      icon: Icons.stars_outlined,
                      isDecimal: true,
                    ),

                    if (selectedTimerType == 'target') ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Allow Overtime Bonus',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                          ),
                          subtitle: Text(
                            'Earn extra points for exceeding target',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[600],
                                ),
                          ),
                          value: allowOvertime,
                          onChanged: (value) =>
                              setState(() => allowOvertime = value),
                          activeColor: accentColor,
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    _buildModernInputField(
                      context: context,
                      isDark: isDark,
                      label: 'Not Done Penalty',
                      controller: noPointsController,
                      color: errorColor,
                      icon: Icons.remove_circle_outline,
                    ),
                    const SizedBox(height: 16),
                    _buildModernInputField(
                      context: context,
                      isDark: isDark,
                      label: 'Postpone Penalty',
                      controller: postponePointsController,
                      color: warningColor,
                      icon: Icons.pause_circle_outline,
                    ),

                    const SizedBox(height: 32),

                    // Save Button
                    Container(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          final basePoints =
                              int.tryParse(basePointsController.text) ?? 10;
                          final noPoints =
                              int.tryParse(noPointsController.text) ?? -10;
                          final postponePoints =
                              int.tryParse(postponePointsController.text) ?? -5;
                          final bonusPerMin =
                              double.tryParse(bonusController.text) ?? 0.1;

                          final updatedConfig = config.copyWith(
                            isEnabled: true,
                            defaultTimerType: selectedTimerType,
                            defaultYesPoints: basePoints,
                            defaultNoPoints: noPoints,
                            defaultPostponePoints: postponePoints,
                            defaultBonusPerMinute: bonusPerMin,
                            allowOvertimeBonus: allowOvertime,
                          );

                          ref
                              .read(
                                completionTypeConfigNotifierProvider.notifier,
                              )
                              .updateConfig(updatedConfig);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Timer configured successfully!',
                              ),
                              backgroundColor: successColor,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Save Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
          );
        },
      ),
    );
  }

  void _openSecureQuitConfigSheet(
    BuildContext context,
    bool isDark,
    CompletionTypeConfig config,
    WidgetRef ref,
  ) async {
    final guard = QuitHabitReportAccessGuard();
    final unlocked = await guard.ensureQuitSettingsAccess(
      context,
      onSecurityEmergencyReset: () async {
        await ref.read(habitNotifierProvider.notifier).loadHabits();
      },
    );
    if (!context.mounted || !unlocked) return;
    _showQuitConfigSheet(context, isDark, config, ref);
  }

  Future<bool> _authorizeQuitVisibilityToggle(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final guard = QuitHabitReportAccessGuard();
    final ok = await guard.ensureQuitSettingsAccess(
      context,
      forcePrompt: true,
      onSecurityEmergencyReset: () async {
        await ref.read(habitNotifierProvider.notifier).loadHabits();
      },
    );
    if (!context.mounted) return false;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passcode verification required to change visibility.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    return true;
  }

  /// Show configuration sheet for Quit type
  void _showQuitConfigSheet(
    BuildContext context,
    bool isDark,
    CompletionTypeConfig config,
    WidgetRef ref,
  ) {
    final dailyRewardController = TextEditingController(
      text: config.defaultDailyReward?.toString() ?? '10',
    );
    final slipPenaltyController = TextEditingController(
      text: config.defaultSlipPenalty?.toString() ?? '-20',
    );
    final penaltyPerUnitController = TextEditingController(
      text: config.defaultPenaltyPerUnit?.toString() ?? '-5',
    );
    final streakProtectionController = TextEditingController(
      text: config.defaultStreakProtection?.toString() ?? '0',
    );
    final costPerUnitController = TextEditingController(
      text: config.defaultCostPerUnit?.toString() ?? '0',
    );

    String selectedSlipCalculation = config.defaultSlipCalculation ?? 'fixed';
    bool enableTemptation = config.enableTemptationTracking ?? true;
    bool hideQuitDefault = config.defaultHideQuitHabit ?? true;
    bool isVerifyingQuitVisibility = false;

    final accentColor = Theme.of(context).colorScheme.primary;
    final successColor = isDark ? Colors.green[400]! : Colors.green[700]!;
    final errorColor = Theme.of(context).colorScheme.error;
    final warningColor = const Color(0xFFCDAF56);
    final amberColor = Colors.amber;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return SheetDismissOnOverscroll(
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
              ),
              child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 10,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D21) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pull Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    Text(
                      'Quit Bad Habit',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure how to track and break bad habits.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section: Daily Reward
                    _buildSectionHeader(context, isDark, 'RESISTANCE REWARD'),
                    const SizedBox(height: 8),
                    Text(
                      'Points earned each day you resist the bad habit.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[600] : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildModernInputField(
                      context: context,
                      isDark: isDark,
                      label: 'Daily Reward Points',
                      controller: dailyRewardController,
                      prefixText: '+',
                      color: successColor,
                      icon: Icons.star_outline,
                    ),
                    const SizedBox(height: 24),

                    // Section: Slip Penalty
                    _buildSectionHeader(context, isDark, 'SLIP PENALTY'),
                    const SizedBox(height: 8),
                    Text(
                      'How to calculate point loss when you slip.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[600] : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Slip Calculation Method
                    _buildMethodCard(
                      context: context,
                      isDark: isDark,
                      title: 'Fixed Penalty',
                      description: 'Same penalty regardless of quantity.',
                      isSelected: selectedSlipCalculation == 'fixed',
                      onTap: () =>
                          setState(() => selectedSlipCalculation = 'fixed'),
                      color: errorColor,
                    ),
                    const SizedBox(height: 8),
                    _buildMethodCard(
                      context: context,
                      isDark: isDark,
                      title: 'Per Unit',
                      description: 'Penalty multiplied by quantity consumed.',
                      isSelected: selectedSlipCalculation == 'perUnit',
                      onTap: () =>
                          setState(() => selectedSlipCalculation = 'perUnit'),
                      color: warningColor,
                    ),
                    const SizedBox(height: 16),

                    if (selectedSlipCalculation == 'fixed')
                      _buildModernInputField(
                        context: context,
                        isDark: isDark,
                        label: 'Slip Penalty (Fixed)',
                        controller: slipPenaltyController,
                        color: errorColor,
                        icon: Icons.remove_circle_outline,
                      ),

                    if (selectedSlipCalculation == 'perUnit')
                      _buildModernInputField(
                        context: context,
                        isDark: isDark,
                        label: 'Penalty Per Unit',
                        controller: penaltyPerUnitController,
                        color: errorColor,
                        icon: Icons.remove_circle_outline,
                      ),
                    const SizedBox(height: 24),

                    // Section: Streak Protection
                    _buildSectionHeader(context, isDark, 'STREAK PROTECTION'),
                    const SizedBox(height: 8),
                    Text(
                      'Allow some slips before breaking your streak.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[600] : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildModernInputField(
                      context: context,
                      isDark: isDark,
                      label: 'Allowed Slips (0 = no protection)',
                      controller: streakProtectionController,
                      color: accentColor,
                      icon: Icons.shield_outlined,
                    ),
                    const SizedBox(height: 24),

                    // Section: Temptation Tracking
                    _buildSectionHeader(context, isDark, 'TEMPTATION TRACKING'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Enable Temptation Logs',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                        ),
                        subtitle: Text(
                          'Track when you felt tempted but resisted (no points)',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[600],
                              ),
                        ),
                        value: enableTemptation,
                        onChanged: (value) =>
                            setState(() => enableTemptation = value),
                        activeColor: amberColor,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section: Visibility
                    _buildSectionHeader(context, isDark, 'VISIBILITY'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Hide quit habits on dashboard',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                        ),
                        subtitle: Text(
                          'If enabled, quit habits stay hidden unless viewed in "Quit" filter',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[600],
                              ),
                        ),
                        value: hideQuitDefault,
                        onChanged: isVerifyingQuitVisibility
                            ? null
                            : (value) async {
                                if (value == hideQuitDefault) return;
                                setState(
                                  () => isVerifyingQuitVisibility = true,
                                );
                                final allowed =
                                    await _authorizeQuitVisibilityToggle(
                                      context,
                                      ref,
                                    );
                                if (!context.mounted) return;
                                setState(
                                  () => isVerifyingQuitVisibility = false,
                                );
                                if (!allowed) return;
                                setState(() => hideQuitDefault = value);
                              },
                        activeColor: accentColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E2230).withValues(alpha: 0.6)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.shield_rounded,
                          color: Color(0xFFEF5350),
                        ),
                        title: Text(
                          'Quit Report Security',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                        ),
                        subtitle: Text(
                          'Passcode and recovery settings for quit report',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        onTap: () async {
                          final guard = QuitHabitReportAccessGuard();
                          final unlocked = await guard.ensureQuitSettingsAccess(
                            context,
                            forcePrompt: true,
                            onSecurityEmergencyReset: () async {
                              await ref
                                  .read(habitNotifierProvider.notifier)
                                  .loadHabits();
                            },
                          );
                          if (!context.mounted || !unlocked) return;

                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const QuitHabitReportSecurityScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section: Cost Tracking (Optional)
                    _buildSectionHeader(
                      context,
                      isDark,
                      'COST TRACKING (OPTIONAL)',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Track money saved by quitting (e.g., \$0.50/cigarette).',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[600] : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildModernInputField(
                      context: context,
                      isDark: isDark,
                      label: 'Cost Per Unit (\$)',
                      controller: costPerUnitController,
                      prefixText: '\$',
                      color: successColor,
                      icon: Icons.attach_money,
                      isDecimal: true,
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    Container(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () async {
                          final dailyReward =
                              int.tryParse(dailyRewardController.text) ?? 10;
                          final slipPenalty =
                              int.tryParse(slipPenaltyController.text) ?? -20;
                          final penaltyPerUnit =
                              int.tryParse(penaltyPerUnitController.text) ?? -5;
                          final streakProtection =
                              int.tryParse(streakProtectionController.text) ??
                              0;
                          final costPerUnit =
                              double.tryParse(costPerUnitController.text) ?? 0;
                          final updatedConfig = config.copyWith(
                            isEnabled: true,
                            defaultDailyReward: dailyReward,
                            defaultSlipPenalty: slipPenalty,
                            defaultSlipCalculation: selectedSlipCalculation,
                            defaultPenaltyPerUnit: penaltyPerUnit,
                            defaultStreakProtection: streakProtection,
                            defaultCostPerUnit: costPerUnit,
                            enableTemptationTracking: enableTemptation,
                            defaultHideQuitHabit: hideQuitDefault,
                          );

                          await ref
                              .read(
                                completionTypeConfigNotifierProvider.notifier,
                              )
                              .updateConfig(updatedConfig);

                          // Apply visibility setting to existing quit habits
                          final notifier = ref.read(
                            habitNotifierProvider.notifier,
                          );
                          await notifier.loadHabits();
                          final habitsState = ref.read(habitNotifierProvider);
                          await habitsState.maybeWhen(
                            data: (habits) async {
                              for (final habit in habits) {
                                if (!habit.isQuitHabit) continue;
                                if (habit.hideQuitHabit == hideQuitDefault)
                                  continue;
                                await notifier.updateHabit(
                                  habit.copyWith(
                                    hideQuitHabit: hideQuitDefault,
                                  ),
                                );
                              }
                            },
                            orElse: () async {},
                          );

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Quit habit settings saved!'),
                              backgroundColor: successColor,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Save Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, bool isDark, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: isDark ? Colors.grey[600] : Colors.grey[500],
      ),
    );
  }

  Widget _buildModernInputField({
    required BuildContext context,
    required bool isDark,
    required String label,
    required TextEditingController controller,
    required Color color,
    required IconData icon,
    String? prefixText,
    bool isDecimal = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: color.withOpacity(0.5)),
            prefixText: prefixText,
            prefixStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: color.withOpacity(0.5), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimerTypeCard({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String description,
    required String example,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(isDark ? 0.2 : 0.15)
              : (isDark ? Colors.black.withOpacity(0.2) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected
                  ? color
                  : (isDark ? Colors.grey[600] : Colors.grey),
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? color
                          : (isDark ? Colors.white : Colors.black),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(isDark ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      example,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isSelected
                            ? color
                            : (isDark ? Colors.grey[400] : color),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodCard({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(isDark ? 0.2 : 0.15)
              : (isDark ? Colors.black.withOpacity(0.2) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected
                  ? color
                  : (isDark ? Colors.grey[600] : Colors.grey),
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? color
                          : (isDark ? Colors.white : Colors.black),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
