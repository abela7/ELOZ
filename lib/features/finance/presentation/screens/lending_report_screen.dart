import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/debt.dart';
import '../../data/models/transaction_category.dart';
import '../../data/services/finance_settings_service.dart';
import '../../utils/currency_utils.dart';
import '../providers/finance_providers.dart';

enum LendingReportRange { day, week, month, year, allTime }

class LendingReportScreen extends ConsumerStatefulWidget {
  const LendingReportScreen({super.key});

  @override
  ConsumerState<LendingReportScreen> createState() =>
      _LendingReportScreenState();
}

class _LendingReportScreenState extends ConsumerState<LendingReportScreen> {
  LendingReportRange _selectedRange = LendingReportRange.month;
  DateTime _anchorDate = _normalize(DateTime.now());
  bool _breakdownExpanded = false;

  static DateTime _normalize(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime _endOfDay(DateTime date) {
    final d = _normalize(date);
    return DateTime(d.year, d.month, d.day, 23, 59, 59, 999, 999);
  }

  static DateTime _startOfWeek(DateTime date) {
    final normalized = _normalize(date);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  static DateTime _endOfMonth(DateTime date) {
    final normalized = _normalize(date);
    return DateTime(normalized.year, normalized.month + 1, 0);
  }

  _DateSpan _resolveDateSpan(List<Debt> debts) {
    switch (_selectedRange) {
      case LendingReportRange.day:
        return _DateSpan(start: _anchorDate, end: _anchorDate);
      case LendingReportRange.week:
        final start = _startOfWeek(_anchorDate);
        return _DateSpan(start: start, end: start.add(const Duration(days: 6)));
      case LendingReportRange.month:
        return _DateSpan(
          start: DateTime(_anchorDate.year, _anchorDate.month, 1),
          end: _endOfMonth(_anchorDate),
        );
      case LendingReportRange.year:
        return _DateSpan(
          start: DateTime(_anchorDate.year, 1, 1),
          end: DateTime(_anchorDate.year, 12, 31),
        );
      case LendingReportRange.allTime:
        final allEventDates = <DateTime>[];
        for (final debt in debts) {
          allEventDates.add(_normalize(debt.createdAt));
          for (final payment in debt.paymentHistory) {
            allEventDates.add(_normalize(payment.paidAt));
          }
        }
        if (allEventDates.isEmpty) {
          final today = _normalize(DateTime.now());
          return _DateSpan(start: today, end: today, isAllTime: true);
        }
        allEventDates.sort((a, b) => a.compareTo(b));
        return _DateSpan(
          start: allEventDates.first,
          end: _normalize(DateTime.now()),
          isAllTime: true,
        );
    }
  }

  void _shiftRange(int step) {
    setState(() {
      switch (_selectedRange) {
        case LendingReportRange.day:
          _anchorDate = _anchorDate.add(Duration(days: step));
          break;
        case LendingReportRange.week:
          _anchorDate = _anchorDate.add(Duration(days: step * 7));
          break;
        case LendingReportRange.month:
          _anchorDate = DateTime(_anchorDate.year, _anchorDate.month + step, 1);
          break;
        case LendingReportRange.year:
          _anchorDate = DateTime(_anchorDate.year + step, _anchorDate.month, 1);
          break;
        case LendingReportRange.allTime:
          break;
      }
    });
  }

  Future<void> _pickAnchorDate() async {
    if (_selectedRange == LendingReportRange.allTime) return;

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchorDate,
      firstDate: DateTime(now.year - 20, 1, 1),
      lastDate: DateTime(now.year + 20, 12, 31),
    );

    if (picked != null) {
      setState(() => _anchorDate = _normalize(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultCurrency =
        ref.watch(defaultCurrencyProvider).value ??
        FinanceSettingsService.fallbackCurrency;
    final debtsAsync = ref.watch(allLentDebtsProvider);
    final categories =
        ref.watch(allExpenseTransactionCategoriesProvider).valueOrNull ?? [];

    final content = SafeArea(
      child: debtsAsync.when(
        data: (debts) {
          final span = _resolveDateSpan(debts);
          final report = _buildReportData(
            debts: debts,
            categories: categories,
            span: span,
          );
          final currency = _resolveDisplayCurrency(report, defaultCurrency);
          final symbol = CurrencyUtils.getCurrencySymbol(currency);
          final periodLabel = _periodLabel(span);

          return Column(
            children: [
              _buildHeader(isDark),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
                  children: [
                    _buildRangeSelector(isDark),
                    const SizedBox(height: 12),
                    if (_selectedRange != LendingReportRange.allTime)
                      _buildDateNavigator(isDark, span),
                    if (_selectedRange != LendingReportRange.allTime)
                      const SizedBox(height: 12),
                    _buildSummaryCard(
                      isDark: isDark,
                      symbol: symbol,
                      periodLabel: periodLabel,
                      lent: report.periodLentByCurrency[currency] ?? 0,
                      collected:
                          report.periodCollectedByCurrency[currency] ?? 0,
                      outstanding: report.outstandingByCurrency[currency] ?? 0,
                    ),
                    const SizedBox(height: 12),
                    _buildQuickStats(
                      isDark: isDark,
                      collectionRate: report.collectionRate,
                      activeCount: report.activeAsOfEnd,
                      overdueCount: report.overdueAsOfEnd,
                      openedCount: report.openedInPeriod,
                    ),
                    const SizedBox(height: 12),
                    _buildLifetimeCard(
                      isDark: isDark,
                      symbol: symbol,
                      totalLent: report.totalLentByCurrency[currency] ?? 0,
                      totalCollected:
                          report.totalCollectedByCurrency[currency] ?? 0,
                    ),
                    const SizedBox(height: 12),
                    _buildCategorySection(
                      isDark: isDark,
                      symbol: symbol,
                      rows: report.categoryRows,
                    ),
                    const SizedBox(height: 12),
                    _buildBreakdownSection(
                      isDark: isDark,
                      symbol: symbol,
                      rows: report.breakdownRows,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );

    return Scaffold(
      backgroundColor: isDark ? Colors.transparent : const Color(0xFFF5F5F7),
      body: isDark ? DarkGradient.wrap(child: content) : content,
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Row(
        children: [
          _iconButton(
            isDark: isDark,
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFFCDAF56), Color(0xFFB8963E)],
              ),
            ),
            child: const Icon(
              Icons.analytics_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lending Report',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Track lent, collected, and outstanding',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.03)
              : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: LendingReportRange.values.map((range) {
            final selected = range == _selectedRange;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedRange = range);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFCDAF56)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _rangeLabel(range),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: selected
                            ? Colors.black87
                            : (isDark ? Colors.white54 : Colors.black54),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDateNavigator(bool isDark, _DateSpan span) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _shiftRange(-1),
            icon: const Icon(Icons.chevron_left_rounded),
            splashRadius: 18,
            color: const Color(0xFFCDAF56),
          ),
          Expanded(
            child: Text(
              _periodLabel(span),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _shiftRange(1),
            icon: const Icon(Icons.chevron_right_rounded),
            splashRadius: 18,
            color: const Color(0xFFCDAF56),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _pickAnchorDate,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFCDAF56).withOpacity(0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: Color(0xFFCDAF56),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required bool isDark,
    required String symbol,
    required String periodLabel,
    required double lent,
    required double collected,
    required double outstanding,
  }) {
    final net = collected - lent;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A1D23), const Color(0xFF12151A)]
              : [Colors.white, const Color(0xFFF8F9FC)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.03),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            periodLabel.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Color(0xFFCDAF56),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _metricValue(
                  isDark: isDark,
                  label: 'Lent',
                  value: '$symbol${lent.toStringAsFixed(2)}',
                  color: const Color(0xFFEF5350),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricValue(
                  isDark: isDark,
                  label: 'Collected',
                  value: '$symbol${collected.toStringAsFixed(2)}',
                  color: const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metricValue(
                  isDark: isDark,
                  label: 'Net Flow',
                  value: '$symbol${net.toStringAsFixed(2)}',
                  color: net >= 0
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFEF5350),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricValue(
                  isDark: isDark,
                  label: 'Outstanding',
                  value: '$symbol${outstanding.toStringAsFixed(2)}',
                  color: const Color(0xFFCDAF56),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricValue({
    required bool isDark,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.black45,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats({
    required bool isDark,
    required double collectionRate,
    required int activeCount,
    required int overdueCount,
    required int openedCount,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              isDark: isDark,
              label: 'Collection Rate',
              value: '${collectionRate.toStringAsFixed(1)}%',
              color: const Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statCard(
              isDark: isDark,
              label: 'Active',
              value: '$activeCount',
              color: const Color(0xFFCDAF56),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statCard(
              isDark: isDark,
              label: 'Overdue',
              value: '$overdueCount',
              color: const Color(0xFFEF5350),
              footer: '$openedCount new',
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required bool isDark,
    required String label,
    required String value,
    required Color color,
    String? footer,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.black45,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          if (footer != null)
            Text(
              footer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLifetimeCard({
    required bool isDark,
    required String symbol,
    required double totalLent,
    required double totalCollected,
  }) {
    final remaining = (totalLent - totalCollected).clamp(0.0, double.infinity);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lifetime Overview',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _miniLine(
                  isDark,
                  'Total Lent',
                  '$symbol${totalLent.toStringAsFixed(2)}',
                  const Color(0xFFEF5350),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniLine(
                  isDark,
                  'Total Collected',
                  '$symbol${totalCollected.toStringAsFixed(2)}',
                  const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniLine(
                  isDark,
                  'Remaining',
                  '$symbol${remaining.toStringAsFixed(2)}',
                  const Color(0xFFCDAF56),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniLine(bool isDark, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection({
    required bool isDark,
    required String symbol,
    required List<_CategoryReportRow> rows,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'By Expense Category',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Text(
              'No lending activity for this range.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            )
          else
            ...rows.take(6).map((row) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: row.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(row.icon, size: 18, color: row.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'Lent $symbol${row.lent.toStringAsFixed(2)}  Collected $symbol${row.collected.toStringAsFixed(2)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white60 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$symbol${row.outstanding.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFCDAF56),
                          ),
                        ),
                        Text(
                          '${row.activeCount} active',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildBreakdownSection({
    required bool isDark,
    required String symbol,
    required List<_BreakdownRow> rows,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _breakdownExpanded,
          onExpansionChanged: (expanded) {
            setState(() => _breakdownExpanded = expanded);
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: const Color(0xFFCDAF56),
          collapsedIconColor: const Color(0xFFCDAF56),
          title: Row(
            children: [
              Text(
                'Period Breakdown',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                '${rows.length} rows',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
          children: [
            if (rows.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No events in selected range.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              )
            else
              ...rows.take(31).map((row) {
                final net = row.collected - row.lent;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.03)
                          : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'L $symbol${row.lent.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEF5350),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'C $symbol${row.collected.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4CAF50),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'N $symbol${net.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: net >= 0
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFEF5350),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _iconButton({
    required bool isDark,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D23) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }

  String _rangeLabel(LendingReportRange range) {
    switch (range) {
      case LendingReportRange.day:
        return 'Day';
      case LendingReportRange.week:
        return 'Week';
      case LendingReportRange.month:
        return 'Month';
      case LendingReportRange.year:
        return 'Year';
      case LendingReportRange.allTime:
        return 'All Time';
    }
  }

  String _periodLabel(_DateSpan span) {
    switch (_selectedRange) {
      case LendingReportRange.day:
        return DateFormat('EEE, MMM d, yyyy').format(span.start);
      case LendingReportRange.week:
        return '${DateFormat('MMM d').format(span.start)} - ${DateFormat('MMM d, yyyy').format(span.end)}';
      case LendingReportRange.month:
        return DateFormat('MMMM yyyy').format(span.start);
      case LendingReportRange.year:
        return DateFormat('yyyy').format(span.start);
      case LendingReportRange.allTime:
        return '${DateFormat('MMM d, yyyy').format(span.start)} - ${DateFormat('MMM d, yyyy').format(span.end)}';
    }
  }

  String _resolveDisplayCurrency(
    _LendingReportData report,
    String defaultCurrency,
  ) {
    final totals = <String, double>{};

    void accumulate(Map<String, double> source) {
      source.forEach((currency, amount) {
        totals[currency] = (totals[currency] ?? 0) + amount.abs();
      });
    }

    accumulate(report.outstandingByCurrency);
    accumulate(report.periodLentByCurrency);
    accumulate(report.periodCollectedByCurrency);

    if (totals.containsKey(defaultCurrency)) {
      return defaultCurrency;
    }

    if (totals.isEmpty) {
      return defaultCurrency;
    }

    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  _LendingReportData _buildReportData({
    required List<Debt> debts,
    required List<TransactionCategory> categories,
    required _DateSpan span,
  }) {
    final categoryById = <String, TransactionCategory>{
      for (final category in categories) category.id: category,
    };

    final periodLentByCurrency = <String, double>{};
    final periodCollectedByCurrency = <String, double>{};
    final outstandingByCurrency = <String, double>{};
    final totalLentByCurrency = <String, double>{};
    final totalCollectedByCurrency = <String, double>{};

    final categoryBuckets = <String, _CategoryBucket>{};
    int activeAsOfEnd = 0;
    int overdueAsOfEnd = 0;
    int openedInPeriod = 0;

    DateTime endOfRange = _endOfDay(span.end);

    for (final debt in debts) {
      final currency = debt.currency;
      final bucket = categoryBuckets.putIfAbsent(
        debt.categoryId,
        () => _CategoryBucket(),
      );

      totalLentByCurrency[currency] =
          (totalLentByCurrency[currency] ?? 0) + debt.originalAmount;

      final inPeriodCreated = span.containsDate(debt.createdAt);
      if (inPeriodCreated) {
        periodLentByCurrency[currency] =
            (periodLentByCurrency[currency] ?? 0) + debt.originalAmount;
        bucket.lent += debt.originalAmount;
        openedInPeriod++;
      }

      for (final payment in debt.paymentHistory) {
        totalCollectedByCurrency[currency] =
            (totalCollectedByCurrency[currency] ?? 0) + payment.amount;

        if (span.containsDate(payment.paidAt)) {
          periodCollectedByCurrency[currency] =
              (periodCollectedByCurrency[currency] ?? 0) + payment.amount;
          bucket.collected += payment.amount;
        }
      }

      final outstanding = debt.balanceAsOfDate(span.end);
      if (outstanding > 0 && debt.existsAsOfDate(span.end)) {
        outstandingByCurrency[currency] =
            (outstandingByCurrency[currency] ?? 0) + outstanding;
        bucket.outstanding += outstanding;
        bucket.activeCount += 1;
        activeAsOfEnd++;

        if (debt.dueDate != null && debt.dueDate!.isBefore(endOfRange)) {
          overdueAsOfEnd++;
        }
      }
    }

    final categoryRows = <_CategoryReportRow>[];
    categoryBuckets.forEach((categoryId, bucket) {
      if (bucket.lent <= 0 &&
          bucket.collected <= 0 &&
          bucket.outstanding <= 0 &&
          bucket.activeCount <= 0) {
        return;
      }

      final category = categoryById[categoryId];
      categoryRows.add(
        _CategoryReportRow(
          id: categoryId,
          name: category?.name ?? 'Uncategorized',
          icon: category?.icon ?? Icons.category_rounded,
          color: category?.color ?? const Color(0xFFCDAF56),
          lent: bucket.lent,
          collected: bucket.collected,
          outstanding: bucket.outstanding,
          activeCount: bucket.activeCount,
        ),
      );
    });

    categoryRows.sort((a, b) {
      final byOutstanding = b.outstanding.compareTo(a.outstanding);
      if (byOutstanding != 0) return byOutstanding;
      return b.lent.compareTo(a.lent);
    });

    final breakdownRows = _buildBreakdownRows(debts, span);
    final totalLentPeriod = periodLentByCurrency.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final totalCollectedPeriod = periodCollectedByCurrency.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final collectionRate = totalLentPeriod > 0
        ? (totalCollectedPeriod / totalLentPeriod) * 100
        : 0.0;

    return _LendingReportData(
      periodLentByCurrency: periodLentByCurrency,
      periodCollectedByCurrency: periodCollectedByCurrency,
      outstandingByCurrency: outstandingByCurrency,
      totalLentByCurrency: totalLentByCurrency,
      totalCollectedByCurrency: totalCollectedByCurrency,
      categoryRows: categoryRows,
      breakdownRows: breakdownRows,
      activeAsOfEnd: activeAsOfEnd,
      overdueAsOfEnd: overdueAsOfEnd,
      openedInPeriod: openedInPeriod,
      collectionRate: collectionRate,
    );
  }

  List<_BreakdownRow> _buildBreakdownRows(List<Debt> debts, _DateSpan span) {
    final rows = <_BreakdownRow>[];
    final isMonthlyBuckets =
        _selectedRange == LendingReportRange.year ||
        _selectedRange == LendingReportRange.allTime;

    final byKey = <DateTime, _BreakdownBucket>{};

    if (isMonthlyBuckets) {
      var cursor = DateTime(span.start.year, span.start.month, 1);
      final last = DateTime(span.end.year, span.end.month, 1);
      while (!cursor.isAfter(last)) {
        byKey[cursor] = _BreakdownBucket();
        cursor = DateTime(cursor.year, cursor.month + 1, 1);
      }
    } else {
      var cursor = span.start;
      while (!cursor.isAfter(span.end)) {
        byKey[cursor] = _BreakdownBucket();
        cursor = cursor.add(const Duration(days: 1));
      }
    }

    DateTime keyOf(DateTime eventDate) {
      final local = _normalize(eventDate);
      if (isMonthlyBuckets) return DateTime(local.year, local.month, 1);
      return local;
    }

    for (final debt in debts) {
      if (span.containsDate(debt.createdAt)) {
        final key = keyOf(debt.createdAt);
        final bucket = byKey[key];
        if (bucket != null) {
          bucket.lent += debt.originalAmount;
        }
      }

      for (final payment in debt.paymentHistory) {
        if (!span.containsDate(payment.paidAt)) continue;
        final key = keyOf(payment.paidAt);
        final bucket = byKey[key];
        if (bucket != null) {
          bucket.collected += payment.amount;
        }
      }
    }

    final entries = byKey.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    for (final entry in entries) {
      final label = isMonthlyBuckets
          ? DateFormat('MMM yyyy').format(entry.key)
          : DateFormat('EEE, MMM d').format(entry.key);
      rows.add(
        _BreakdownRow(
          label: label,
          lent: entry.value.lent,
          collected: entry.value.collected,
        ),
      );
    }

    return rows;
  }
}

class _DateSpan {
  final DateTime start;
  final DateTime end;
  final bool isAllTime;

  const _DateSpan({
    required this.start,
    required this.end,
    this.isAllTime = false,
  });

  bool containsDate(DateTime date) {
    final normalized = _LendingReportScreenState._normalize(date);
    return !normalized.isBefore(start) && !normalized.isAfter(end);
  }
}

class _CategoryBucket {
  double lent = 0;
  double collected = 0;
  double outstanding = 0;
  int activeCount = 0;
}

class _BreakdownBucket {
  double lent = 0;
  double collected = 0;
}

class _LendingReportData {
  final Map<String, double> periodLentByCurrency;
  final Map<String, double> periodCollectedByCurrency;
  final Map<String, double> outstandingByCurrency;
  final Map<String, double> totalLentByCurrency;
  final Map<String, double> totalCollectedByCurrency;
  final List<_CategoryReportRow> categoryRows;
  final List<_BreakdownRow> breakdownRows;
  final int activeAsOfEnd;
  final int overdueAsOfEnd;
  final int openedInPeriod;
  final double collectionRate;

  const _LendingReportData({
    required this.periodLentByCurrency,
    required this.periodCollectedByCurrency,
    required this.outstandingByCurrency,
    required this.totalLentByCurrency,
    required this.totalCollectedByCurrency,
    required this.categoryRows,
    required this.breakdownRows,
    required this.activeAsOfEnd,
    required this.overdueAsOfEnd,
    required this.openedInPeriod,
    required this.collectionRate,
  });
}

class _CategoryReportRow {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final double lent;
  final double collected;
  final double outstanding;
  final int activeCount;

  const _CategoryReportRow({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.lent,
    required this.collected,
    required this.outstanding,
    required this.activeCount,
  });
}

class _BreakdownRow {
  final String label;
  final double lent;
  final double collected;

  const _BreakdownRow({
    required this.label,
    required this.lent,
    required this.collected,
  });
}
