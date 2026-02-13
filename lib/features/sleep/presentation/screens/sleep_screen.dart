import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/notifications/services/universal_notification_scheduler.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/sleep_record.dart';
import '../../data/models/sleep_factor.dart';
import '../../data/services/sleep_target_service.dart';
import '../providers/sleep_providers.dart';
import '../../../../core/widgets/date_navigator_widget.dart';
import 'sleep_settings_screen.dart';
import 'sleep_target_screen.dart';
import 'sleep_history_screen.dart';
import 'sleep_statistics_screen.dart';
import 'sleep_debt_report_screen.dart';
import '../../data/models/sleep_debt_consistency.dart';

/// Sleep Screen - Sleep Mini-App Dashboard (matching Tasks/Habits dashboard structure)
class SleepScreen extends ConsumerStatefulWidget {
  const SleepScreen({super.key});

  @override
  ConsumerState<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends ConsumerState<SleepScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isSearching = false;
  bool _showNaps = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await UniversalNotificationScheduler().syncAll();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sleepRecordsAsync = ref.watch(sleepRecordsStreamProvider);
    final targetSettingsAsync = ref.watch(sleepTargetSettingsProvider);

    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(
              child: _buildContent(
                context,
                isDark,
                sleepRecordsAsync,
                targetSettingsAsync,
              ),
            )
          : _buildContent(
              context,
              isDark,
              sleepRecordsAsync,
              targetSettingsAsync,
            ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    AsyncValue<List<SleepRecord>> sleepRecordsAsync,
    AsyncValue<SleepTargetSettings> targetSettingsAsync,
  ) {
    return Scaffold(
      backgroundColor: isDark ? Colors.transparent : const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: 'Search sleep records...',
                  hintStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {});
                },
              )
            : const Text('Sleep'),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                });
              },
              tooltip: 'Close Search',
            )
          else
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
              tooltip: 'Search Sleep Records',
            ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: () {
                _showAddSleepPlaceholder(context);
              },
              tooltip: 'Log Sleep',
            ),
        ],
      ),
      body: SafeArea(
        child: sleepRecordsAsync.when(
          data: (allRecords) {
            if (_isSearching && _searchController.text.isNotEmpty) {
              return _buildSearchResults(context, isDark, allRecords);
            }
            return _buildSleepContent(
              context,
              isDark,
              allRecords,
              targetSettingsAsync,
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) =>
              Center(child: Text('Error loading sleep records: $error')),
        ),
      ),
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    bool isDark,
    List<SleepRecord> allRecords,
  ) {
    final searchQuery = _searchController.text.toLowerCase();
    final filteredRecords = allRecords.where((r) {
      final dateStr = DateFormat('MMM d, yyyy').format(r.bedTime).toLowerCase();
      final qualityStr = r.qualityDisplayName.toLowerCase();
      final notesStr = (r.notes ?? '').toLowerCase();
      return dateStr.contains(searchQuery) ||
          qualityStr.contains(searchQuery) ||
          notesStr.contains(searchQuery);
    }).toList();

    if (filteredRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: isDark ? Colors.white10 : Colors.grey[200],
            ),
            const SizedBox(height: 16),
            Text(
              'No sleep records match your search',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
      itemCount: filteredRecords.length,
      itemBuilder: (context, index) {
        final record = filteredRecords[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SleepRecordCard(
            record: record,
            isDark: isDark,
            onTap: () {
              _showSleepDetailPlaceholder(context, record);
            },
          ),
        );
      },
    );
  }

  Widget _buildSleepContent(
    BuildContext context,
    bool isDark,
    List<SleepRecord> allRecords,
    AsyncValue<SleepTargetSettings> targetSettingsAsync,
  ) {
    // Filter records for selected date
    final recordsForDate = allRecords.where((r) {
      final recordDate = DateTime(
        r.bedTime.year,
        r.bedTime.month,
        r.bedTime.day,
      );
      final selectedDateOnly = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      return recordDate == selectedDateOnly;
    }).toList();

    final napRecords = recordsForDate.where((r) => r.isNap).toList();
    final displayRecords = recordsForDate
      ..sort((a, b) => b.bedTime.compareTo(a.bedTime));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
          HapticFeedback.selectionClick();
          setState(
            () =>
                _selectedDate = _selectedDate.subtract(const Duration(days: 1)),
          );
        } else if (details.primaryVelocity != null &&
            details.primaryVelocity! < -500) {
          HapticFeedback.selectionClick();
          setState(
            () => _selectedDate = _selectedDate.add(const Duration(days: 1)),
          );
        }
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          const SizedBox(height: 8),
          // Date Navigator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: DateNavigatorWidget(
              selectedDate: _selectedDate,
              onDateChanged: (newDate) =>
                  setState(() => _selectedDate = newDate),
            ),
          ),
          const SizedBox(height: 16),

          // Target Progress – how sleep compares to target
          targetSettingsAsync.when(
            data: (settings) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildTargetProgressCard(
                context,
                isDark,
                settings,
                recordsForDate,
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // Sleep Debt + Consistency (Phase 1)
          ref.watch(sleepDebtConsistencyProvider(_selectedDate)).when(
                data: (dc) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildDebtConsistencyCard(context, isDark, dc),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
          const SizedBox(height: 16),

          // Quick Actions Row (4 items)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildQuickActions(context, isDark),
          ),
          const SizedBox(height: 20),

          // Records Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "TODAY'S RECORDS",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFCDAF56),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                if (displayRecords.isEmpty)
                  _buildEmptyState(isDark)
                else
                  ...displayRecords.map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SleepRecordCard(
                        record: record,
                        isDark: isDark,
                        targetSettings: targetSettingsAsync.valueOrNull,
                        onTap: () =>
                            _showSleepDetailPlaceholder(context, record),
                      ),
                    ),
                  ),
                if (napRecords.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _NapsAccordion(
                    naps: napRecords,
                    isDark: isDark,
                    isExpanded: _showNaps,
                    onExpansionChanged: (expanded) =>
                        setState(() => _showNaps = expanded),
                    onNapTap: (record) =>
                        _showSleepDetailPlaceholder(context, record),
                  ),
                ],
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => _showStatisticsPlaceholder(context),
                    child: const Text(
                      'View Statistics',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFCDAF56),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.add_rounded,
            label: 'Log',
            isDark: isDark,
            onTap: () => _showAddSleepPlaceholder(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.list_rounded,
            label: 'History',
            isDark: isDark,
            onTap: () => _showViewAllPlaceholder(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.assessment_rounded,
            label: 'Report',
            isDark: isDark,
            onTap: () => _showStatisticsPlaceholder(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.settings_rounded,
            label: 'Settings',
            isDark: isDark,
            onTap: () => _showSettingsPlaceholder(context),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetProgressCard(
    BuildContext context,
    bool isDark,
    SleepTargetSettings settings,
    List<SleepRecord> records,
  ) {
    final mainSleep = records.where((r) => !r.isNap).toList();
    final totalHours = mainSleep.fold<double>(
      0,
      (sum, r) => sum + r.actualSleepHours,
    );
    final targetHours = settings.targetHours;
    final progress = targetHours > 0 ? (totalHours / targetHours) : 0.0;

    // Only show status when we have logged sleep; otherwise show neutral "No record"
    final bool hasRecord = mainSleep.isNotEmpty;
    final SleepStatus status = hasRecord
        ? settings.getStatusForHours(totalHours)
        : SleepStatus.fair; // neutral placeholder, we use custom label below
    final SleepStatusStyle style = hasRecord
        ? settings.getStatusStyle(status)
        : SleepStatusStyle(
            colorValue: isDark ? 0xFF9E9E9E : 0xFF757575,
            iconCodePoint: Icons.remove_circle_outline.codePoint,
          );
    final statusLabel = hasRecord
        ? switch (status) {
            SleepStatus.dangerous => 'Dangerous',
            SleepStatus.poor => 'Poor',
            SleepStatus.fair => 'Fair',
            SleepStatus.healthy => 'Healthy',
            SleepStatus.extended => 'Extended',
            SleepStatus.overslept => 'Overslept',
          }
        : 'No record';

    String _fmtTarget(double h) {
      final hi = h.floor();
      final m = ((h - hi) * 60).round();
      return m == 0 ? '${hi}h' : '${hi}h ${m}m';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target: ${_fmtTarget(targetHours)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          totalHours > 0
                              ? '${totalHours.toStringAsFixed(1)}h'
                              : '—',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          ' / ${_fmtTarget(targetHours)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    targetHours > 0 && totalHours > 0
                        ? '${(progress * 100).toStringAsFixed(0)}%'
                        : '—',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: style.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: style.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(style.iconData, size: 14, color: style.color),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: style.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.35),
              minHeight: 8,
              backgroundColor: isDark
                  ? AppColors.surfaceDark
                  : const Color(0xFFEDE9E0),
              valueColor: AlwaysStoppedAnimation<Color>(style.color),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SleepTargetScreen(),
              ),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Change target',
              style: TextStyle(
                color: Color(0xFFCDAF56),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtConsistencyCard(
    BuildContext context,
    bool isDark,
    SleepDebtConsistency dc,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '7-day sleep debt',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : Colors.black45,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dc.formattedWeeklyDebt,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: dc.hasDebt
                        ? AppColors.error
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                if (dc.dailyDebtMinutes != null && dc.dailyDebtMinutes! > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Selected night: ${dc.formattedDailyDebt}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: 1,
            height: 48,
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Bedtime consistency',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : Colors.black45,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                if (dc.hasEnoughDataForConsistency &&
                    dc.consistencyScorePercent != null) ...[
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: dc.consistencyScorePercent! / 100,
                          strokeWidth: 5,
                          backgroundColor: isDark
                              ? Colors.white10
                              : Colors.black.withOpacity(0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            dc.consistencyScorePercent! >= 70
                                ? AppColors.success
                                : dc.consistencyScorePercent! >= 50
                                    ? AppColors.warning
                                    : AppColors.error,
                          ),
                        ),
                        Text(
                          '${dc.consistencyScorePercent}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dc.nightsInWindow}/${dc.totalNightsWithData} nights',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Insufficient data',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SleepDebtReportScreen(),
              ),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'View Debt Report',
              style: TextStyle(
                color: Color(0xFFCDAF56),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(isDark ? 0.1 : 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bedtime_rounded,
              size: 40,
              color: AppColors.gold.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No sleep records today',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the Log button to record your sleep',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  // Placeholder functions
  void _showAddSleepPlaceholder(BuildContext context) {
    HapticFeedback.mediumImpact();
    final selectedDateOnly = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SleepHistoryScreen(
          openNewLogOnMount: true,
          initialDateForNewLog: selectedDateOnly,
        ),
      ),
    ).then((result) {
      if (result != null && result is DateTime) {
        setState(() => _selectedDate = result);
      }
    });
  }

  void _showSleepDetailPlaceholder(BuildContext context, SleepRecord record) {
    // Navigate to history which now handles viewing/editing
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SleepHistoryScreen()));
  }

  void _showViewAllPlaceholder(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SleepHistoryScreen()));
  }

  void _showSettingsPlaceholder(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SleepSettingsScreen()),
    );
  }

  void _showStatisticsPlaceholder(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SleepStatisticsScreen()),
    );
  }
}

/// Quick Action Button - Design guide style (compact for 4-in-row)
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
          borderRadius: BorderRadius.circular(16),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.goldOpacity02
                    : AppColors.goldOpacity02,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: const Color(0xFFCDAF56)),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

/// Factor chips showing name with icon - small, compact, handles good/bad types
class _FactorTags extends ConsumerWidget {
  final List<String> factorIds;
  final bool isDark;

  const _FactorTags({required this.factorIds, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final factorsAsync = ref.watch(sleepFactorsStreamProvider);
    return factorsAsync.when(
      data: (allFactors) {
        final factors = allFactors
            .where((f) => factorIds.contains(f.id))
            .toList();
        if (factors.isEmpty) return const SizedBox.shrink();
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: factors.map((factor) => _buildChip(factor)).toList(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildChip(SleepFactor factor) {
    // Use semantic colors for good vs bad factors
    final chipColor = factor.isGood
        ? const Color(0xFF4CAF50) // Green for good
        : const Color(0xFFEF5350); // Red for bad

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: chipColor.withOpacity(isDark ? 0.3 : 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(factor.icon, size: 14, color: chipColor),
          const SizedBox(width: 6),
          Text(
            factor.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: chipColor,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

/// Sleep Record Card - Modern, clean design with premium feel
class _SleepRecordCard extends ConsumerWidget {
  final SleepRecord record;
  final bool isDark;
  final SleepTargetSettings? targetSettings;
  final VoidCallback? onTap;

  const _SleepRecordCard({
    required this.record,
    required this.isDark,
    this.targetSettings,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qualityColor = record.qualityColor;
    final score = record.sleepScore ?? record.calculateSleepScore();
    String? statusLabel;
    SleepStatusStyle? statusStyle;
    Color? statusColor;
    IconData? statusIcon;

    if (targetSettings != null && !record.isNap) {
      final status = targetSettings!.getStatusForHours(record.actualSleepHours);
      statusStyle = targetSettings!.getStatusStyle(status);
      statusLabel = switch (status) {
        SleepStatus.dangerous => 'Dangerous',
        SleepStatus.poor => 'Poor',
        SleepStatus.fair => 'Fair',
        SleepStatus.healthy => 'Healthy',
        SleepStatus.extended => 'Extended',
        SleepStatus.overslept => 'Overslept',
      };
      statusColor = statusStyle.color;
      statusIcon = statusStyle.iconData;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.blackOpacity005,
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Quality icon + Title + Grade badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Quality indicator with gradient background
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            qualityColor.withOpacity(isDark ? 0.25 : 0.15),
                            qualityColor.withOpacity(isDark ? 0.15 : 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: qualityColor.withOpacity(isDark ? 0.3 : 0.2),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          record.qualityEmoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Title and time info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.isNap ? 'Nap Session' : 'Sleep Session',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 13,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${DateFormat('h:mm a').format(record.bedTime)} – ${DateFormat('h:mm a').format(record.wakeTime)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Grade badge - premium floating design
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.gold, Color(0xFFE1C877)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isDark
                            ? [
                                BoxShadow(
                                  color: AppColors.gold.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: AppColors.gold.withOpacity(0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Text(
                        record.scoreGradeDisplay,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E1E1E),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Stats row: Duration and Status badges
                Row(
                  children: [
                    // Duration chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : const Color(0xFFE8E8E8),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bedtime_rounded,
                            size: 14,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            record.formattedDuration,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status badge (if applicable)
                    if (statusLabel != null && statusColor != null) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(isDark ? 0.15 : 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: statusColor.withOpacity(isDark ? 0.3 : 0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              statusIcon ?? Icons.info_rounded,
                              size: 12,
                              color: statusColor,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Score indicator
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppColors.gold.withOpacity(isDark ? 0.6 : 0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${score.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Factors section (if present)
                if (record.factorsBeforeSleep != null &&
                    record.factorsBeforeSleep!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withOpacity(0.06),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        Icons.psychology_rounded,
                        size: 14,
                        color: isDark
                            ? Colors.white30
                            : Colors.black.withOpacity(0.3),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'FACTORS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: isDark
                              ? Colors.white30
                              : Colors.black.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _FactorTags(
                    factorIds: record.factorsBeforeSleep!,
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Naps Accordion - Design guide style
class _NapsAccordion extends StatelessWidget {
  final List<SleepRecord> naps;
  final bool isDark;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final ValueChanged<SleepRecord> onNapTap;

  const _NapsAccordion({
    required this.naps,
    required this.isDark,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onNapTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => onExpansionChanged(!isExpanded),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(isDark ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.bedtime_rounded,
                      size: 20,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nap Sessions',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${naps.length} session${naps.length != 1 ? 's' : ''} recorded',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withOpacity(0.06),
                  ),
                  const SizedBox(height: 12),
                  ...naps.map(
                    (nap) => _NapCard(
                      nap: nap,
                      isDark: isDark,
                      onTap: () => onNapTap(nap),
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

/// Nap Card - Modern compact design matching main sleep card
class _NapCard extends ConsumerWidget {
  final SleepRecord nap;
  final bool isDark;
  final VoidCallback onTap;

  const _NapCard({
    required this.nap,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = nap.sleepScore ?? nap.calculateSleepScore();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Quality indicator
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            nap.qualityColor.withOpacity(isDark ? 0.25 : 0.15),
                            nap.qualityColor.withOpacity(isDark ? 0.15 : 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: nap.qualityColor.withOpacity(
                            isDark ? 0.3 : 0.2,
                          ),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          nap.qualityEmoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title and time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nap Session',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${DateFormat('h:mm a').format(nap.bedTime)} – ${DateFormat('h:mm a').format(nap.wakeTime)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Grade badge - smaller for nap
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.gold.withOpacity(isDark ? 0.4 : 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        nap.scoreGradeDisplay,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Duration and score row
                Row(
                  children: [
                    Icon(
                      Icons.bedtime_rounded,
                      size: 13,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      nap.formattedDuration,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.star_rounded,
                      size: 13,
                      color: AppColors.gold.withOpacity(isDark ? 0.6 : 0.8),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${score.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),

                // Factors section (if present)
                if (nap.factorsBeforeSleep != null &&
                    nap.factorsBeforeSleep!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withOpacity(0.06),
                  ),
                  const SizedBox(height: 10),
                  _FactorTags(
                    factorIds: nap.factorsBeforeSleep!,
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
