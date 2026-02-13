import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../../../core/theme/color_schemes.dart';
import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/widgets/icon_picker_widget.dart';
import '../../../../core/widgets/color_picker_widget.dart';
import '../../data/models/debt.dart';
import '../../data/models/debt_category.dart';
import '../../notifications/finance_notification_scheduler.dart';
import '../providers/finance_providers.dart';
import '../../notifications/finance_notification_creator_context.dart';
import '../widgets/finance_notification_hub_link.dart';
import '../widgets/universal_reminder_section.dart';
import '../../data/models/bill_reminder.dart';
import '../../utils/currency_utils.dart';
import '../../data/services/finance_settings_service.dart';

/// Enum for debt status filter
enum DebtStatusFilter { all, active, overdue, paidOff }

/// Enum for debt sorting options
enum DebtSortBy { amount, dueDate, name, dateAdded }

/// Enum for sort direction
enum SortDirection { ascending, descending }

/// Debts Screen - View and manage all debts organized by category
class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  String? _selectedCategoryId;

  // Filter & Sort State
  Set<String> _filterCategoryIds = {}; // Empty = all categories
  DebtStatusFilter _statusFilter = DebtStatusFilter.all;
  DebtSortBy _sortBy = DebtSortBy.amount;
  SortDirection _sortDirection = SortDirection.descending;

  // Helper to check if any filter is active
  bool get _hasActiveFilters =>
      _filterCategoryIds.isNotEmpty || _statusFilter != DebtStatusFilter.all;

  /// Apply filters to debts list
  List<Debt> _applyFilters(List<Debt> debts) {
    return debts.where((debt) {
      // Category filter
      if (_filterCategoryIds.isNotEmpty &&
          !_filterCategoryIds.contains(debt.categoryId)) {
        return false;
      }

      // Status filter
      switch (_statusFilter) {
        case DebtStatusFilter.active:
          if (!debt.isActive) return false;
          break;
        case DebtStatusFilter.overdue:
          if (!debt.isOverdue) return false;
          break;
        case DebtStatusFilter.paidOff:
          if (!debt.isPaidOff) return false;
          break;
        case DebtStatusFilter.all:
          break;
      }

      return true;
    }).toList();
  }

  /// Apply sorting to debts list
  List<Debt> _applySort(List<Debt> debts) {
    final sorted = List<Debt>.from(debts);

    sorted.sort((a, b) {
      int comparison;

      switch (_sortBy) {
        case DebtSortBy.amount:
          comparison = a.currentBalance.compareTo(b.currentBalance);
          break;
        case DebtSortBy.dueDate:
          // Nulls (no due date) go to end
          if (a.dueDate == null && b.dueDate == null) {
            comparison = 0;
          } else if (a.dueDate == null) {
            comparison = 1;
          } else if (b.dueDate == null) {
            comparison = -1;
          } else {
            comparison = a.dueDate!.compareTo(b.dueDate!);
          }
          break;
        case DebtSortBy.name:
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case DebtSortBy.dateAdded:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
      }

      return _sortDirection == SortDirection.ascending
          ? comparison
          : -comparison;
    });

    return sorted;
  }

  /// Calculate filtered total by currency
  Map<String, double> _calculateFilteredTotal(List<Debt> filteredDebts) {
    final Map<String, double> totals = {};

    for (final debt in filteredDebts) {
      if (debt.isActive) {
        totals[debt.currency] =
            (totals[debt.currency] ?? 0) + debt.currentBalance;
      }
    }

    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoriesAsync = ref.watch(allDebtCategoriesProvider);
    final debtsAsync = ref.watch(allDebtsProvider);

    return categoriesAsync.when(
      data: (categories) => debtsAsync.when(
        data: (allDebts) {
          // Keep totals and list derived from the same source to avoid
          // mismatches between header values and visible records.
          final totals = _calculateFilteredTotal(allDebts);
          final isDebtFree = totals.isEmpty;

          // Define a greenish tint for debt-free state
          final Color? debtFreeBg = isDebtFree
              ? (isDark ? const Color(0xFF1B2E1C) : const Color(0xFFE8F5E9))
              : null;

          // Apply filters and sorting
          final filteredDebts = _applyFilters(allDebts);
          final sortedDebts = _applySort(filteredDebts);
          final filteredTotals = _hasActiveFilters
              ? _calculateFilteredTotal(filteredDebts)
              : totals;

          return Scaffold(
            body: Container(
              decoration: isDark
                  ? (isDebtFree
                        ? BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFF1B2E1C),
                                const Color(0xFF121417),
                              ],
                            ),
                          )
                        : DarkGradient.decoration())
                  : BoxDecoration(color: debtFreeBg ?? const Color(0xFFF8F9FA)),
              child: SafeArea(
                child: Column(
                  children: [
                    _buildHeader(
                      context,
                      isDark,
                      filteredTotals,
                      isFiltered: _hasActiveFilters,
                      originalTotals: totals,
                    ),
                    // Filter & Sort Bar
                    if (!isDebtFree)
                      _buildFilterSortBar(
                        context,
                        isDark,
                        categories,
                        allDebts,
                      ),
                    Expanded(
                      child: _buildContent(
                        context,
                        isDark,
                        categories,
                        sortedDebts,
                        hasActiveFilters: _hasActiveFilters,
                      ),
                    ),
                    _buildBottomBar(context, isDark),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      ),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  /// Build the filter and sort bar
  Widget _buildFilterSortBar(
    BuildContext context,
    bool isDark,
    List<DebtCategory> categories,
    List<Debt> allDebts,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          // Filter Button
          _buildFilterChip(
            context,
            isDark,
            icon: Icons.filter_list_rounded,
            label: _hasActiveFilters ? 'Filtered' : 'Filter',
            isActive: _hasActiveFilters,
            onTap: () => _showFilterSheet(context, isDark, categories),
          ),
          const SizedBox(width: 8),
          // Sort Button
          _buildFilterChip(
            context,
            isDark,
            icon: _sortDirection == SortDirection.descending
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            label: _getSortLabel(),
            isActive: true,
            onTap: () => _showSortSheet(context, isDark),
          ),
          const Spacer(),
          // Clear Filters (if any active)
          if (_hasActiveFilters)
            GestureDetector(
              onTap: () {
                setState(() {
                  _filterCategoryIds = {};
                  _statusFilter = DebtStatusFilter.all;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark
                    ? const Color(0xFFCDAF56).withOpacity(0.15)
                    : const Color(0xFFCDAF56).withOpacity(0.1))
              : (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.03)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? const Color(0xFFCDAF56).withOpacity(0.3)
                : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive
                  ? const Color(0xFFCDAF56)
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? const Color(0xFFCDAF56)
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSortLabel() {
    switch (_sortBy) {
      case DebtSortBy.amount:
        return 'Amount';
      case DebtSortBy.dueDate:
        return 'Due Date';
      case DebtSortBy.name:
        return 'Name';
      case DebtSortBy.dateAdded:
        return 'Date Added';
    }
  }

  /// Show debt calculator bottom sheet
  void _showDebtCalculator(BuildContext context, bool isDark) {
    final debtsAsync = ref.read(allDebtsProvider);
    debtsAsync.whenData((debts) {
      final activeDebts = debts.where((d) => d.isActive).toList();
      if (activeDebts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active debts to calculate.')),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) =>
            _DebtCalculatorSheet(isDark: isDark, debts: activeDebts),
      );
    });
  }

  /// Show filter bottom sheet
  void _showFilterSheet(
    BuildContext context,
    bool isDark,
    List<DebtCategory> categories,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterSheet(
        isDark: isDark,
        categories: categories,
        selectedCategoryIds: _filterCategoryIds,
        statusFilter: _statusFilter,
        onApply: (categoryIds, status) {
          setState(() {
            _filterCategoryIds = categoryIds;
            _statusFilter = status;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  /// Show sort bottom sheet
  void _showSortSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SortSheet(
        isDark: isDark,
        currentSortBy: _sortBy,
        currentDirection: _sortDirection,
        onApply: (sortBy, direction) {
          setState(() {
            _sortBy = sortBy;
            _sortDirection = direction;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withOpacity(0.2)
            : Colors.white.withOpacity(0.5),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _showAddDebtDialog(context, isDark),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'Add New Debt',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade400,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBottomActionChip(
                context,
                isDark,
                icon: Icons.calculate_outlined,
                label: 'Simulator',
                onTap: () => _showDebtCalculator(context, isDark),
              ),
              const SizedBox(width: 12),
              _buildBottomActionChip(
                context,
                isDark,
                icon: Icons.category_outlined,
                label: 'Categories',
                onTap: () => _showDebtCategoriesDialog(context, isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionChip(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    Map<String, double> totals, {
    bool isFiltered = false,
    Map<String, double>? originalTotals,
  }) {
    final isDebtFree = totals.isEmpty && (originalTotals?.isEmpty ?? true);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Debt Management',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      isDebtFree
                          ? 'You are doing great!'
                          : 'Track and pay off your debts',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const FinanceNotificationHubLink(compact: true),
            ],
          ),
          const SizedBox(height: 24),
          // Total Debt Summary Card - Clean & Minimal
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDebtFree
                  ? (isDark
                        ? const Color(0xFF2E7D32).withOpacity(0.2)
                        : Colors.green.shade50)
                  : (isDark
                        ? const Color(0xFFC62828).withOpacity(0.15)
                        : Colors.red.shade50),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDebtFree
                    ? (isDark
                          ? Colors.green.withOpacity(0.3)
                          : Colors.green.shade200)
                    : (isDark
                          ? Colors.red.withOpacity(0.3)
                          : Colors.red.shade200),
                width: 1,
              ),
            ),
            child: isDebtFree
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF43A047),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Debt Free!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.green.shade300
                              : Colors.green.shade800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You have no active debts. Keep it up!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                isFiltered ? 'Filtered Total' : 'Total Owed',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black54,
                                ),
                              ),
                              if (isFiltered) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFCDAF56,
                                    ).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'FILTERED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFCDAF56),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: isDark ? Colors.white30 : Colors.black26,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Show filtered totals
                      if (totals.isEmpty && isFiltered)
                        Text(
                          'No matching debts',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        )
                      else
                        ...totals.entries.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${CurrencyUtils.getCurrencySymbol(e.key)}${e.value.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                        ),
                      // Show original total when filtered
                      if (isFiltered &&
                          originalTotals != null &&
                          originalTotals.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Total: ${originalTotals.entries.map((e) => '${CurrencyUtils.getCurrencySymbol(e.key)}${e.value.toStringAsFixed(2)}').join(' + ')}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    List<DebtCategory> categories,
    List<Debt> debts, {
    required bool hasActiveFilters,
  }) {
    if (debts.isEmpty) {
      if (hasActiveFilters) {
        return _buildEmptyState(
          isDark,
          title: 'No matching debts',
          subtitle: 'Try clearing filters to see all records.',
        );
      }
      return _buildEmptyState(isDark);
    }

    final categoriesById = {
      for (final category in categories) category.id: category,
    };
    final debtsByCategoryId = <String, List<Debt>>{};
    for (final debt in debts) {
      debtsByCategoryId.putIfAbsent(debt.categoryId, () => <Debt>[]).add(debt);
    }

    final sections = <_DebtCategorySection>[];

    // Keep known debt-category ordering first.
    for (final category in categories) {
      final categoryDebts = debtsByCategoryId[category.id];
      if (categoryDebts == null || categoryDebts.isEmpty) continue;
      sections.add(
        _DebtCategorySection(
          category: category,
          debts: categoryDebts,
          addDebtCategoryId: category.id,
        ),
      );
    }

    // Include debts whose category IDs are no longer present in debt categories.
    final unknownCategoryIds =
        debtsByCategoryId.keys
            .where((id) => !categoriesById.containsKey(id))
            .toList()
          ..sort();

    for (final unknownId in unknownCategoryIds) {
      final categoryDebts = debtsByCategoryId[unknownId]!;
      sections.add(
        _DebtCategorySection(
          category: DebtCategory(
            id: unknownId,
            name: 'Uncategorized',
            description: 'Category missing',
            icon: Icons.help_outline_rounded,
            colorValue: Colors.grey.shade600.value,
            sortOrder: 9999,
          ),
          debts: categoryDebts,
          // Avoid passing an unknown category ID into Add Debt sheet.
          addDebtCategoryId: null,
        ),
      );
    }

    if (sections.isEmpty) {
      if (hasActiveFilters) {
        return _buildEmptyState(
          isDark,
          title: 'No matching debts',
          subtitle: 'Try clearing filters to see all records.',
        );
      }
      return _buildEmptyState(isDark);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        return _buildCategoryCard(
          context,
          isDark,
          section.category,
          section.debts,
          addDebtCategoryId: section.addDebtCategoryId,
        );
      },
    );
  }

  Widget _buildEmptyState(
    bool isDark, {
    String title = 'No active debts',
    String? subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.green.withOpacity(0.05)
                    : Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.spa_rounded, // Peaceful icon for relief
                size: 64,
                color: isDark ? Colors.green.shade300 : Colors.green.shade400,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.green.shade900,
                letterSpacing: 0.5,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    bool isDark,
    DebtCategory category,
    List<Debt> debts, {
    String? addDebtCategoryId,
  }) {
    final isExpanded = _selectedCategoryId == category.id;
    final activeDebts = debts.where((d) => d.isActive).toList();
    final hasSingleActiveDebt = activeDebts.length == 1;
    final hasSingleDebt = debts.length == 1;
    final totalOwed = activeDebts.fold<double>(
      0,
      (sum, d) => sum + d.currentBalance,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.03),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Category Header
          InkWell(
            onTap: () async {
              if (hasSingleActiveDebt) {
                await _openDebtDetailsScreen(context, activeDebts.first);
                return;
              }
              if (hasSingleDebt) {
                await _openDebtDetailsScreen(context, debts.first);
                return;
              }

              setState(() {
                _selectedCategoryId = isExpanded ? null : category.id;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: category.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      category.icon ?? Icons.category_rounded,
                      color: category.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (activeDebts.isNotEmpty)
                          Text(
                            '${activeDebts.length} active debt${activeDebts.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (totalOwed > 0) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          activeDebts.isNotEmpty
                              ? '${CurrencyUtils.getCurrencySymbol(activeDebts.first.currency)}${totalOwed.toStringAsFixed(2)}'
                              : '${CurrencyUtils.getCurrencySymbol(FinanceSettingsService.fallbackCurrency)}0.00',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade400,
                          ),
                        ),
                        Text(
                          'owed',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (hasSingleActiveDebt || hasSingleDebt)
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: isDark ? Colors.white54 : Colors.black45,
                    )
                  else
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Expanded Debts List
          if (isExpanded) ...[
            Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
            if (debts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 48,
                      color: Colors.green.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No debts in this category',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => _showAddDebtDialog(
                        context,
                        isDark,
                        categoryId: addDebtCategoryId,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Debt'),
                    ),
                  ],
                ),
              )
            else
              ...debts.map((debt) => _buildDebtTile(context, isDark, debt)),
            // Add button at bottom of category
            if (debts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextButton.icon(
                  onPressed: () => _showAddDebtDialog(
                    context,
                    isDark,
                    categoryId: addDebtCategoryId,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Debt to Category'),
                  style: TextButton.styleFrom(foregroundColor: category.color),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDebtTile(BuildContext context, bool isDark, Debt debt) {
    final progress = debt.paymentProgress;

    return InkWell(
      onTap: () => _openDebtDetailsScreen(context, debt),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            debt.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                              decoration: debt.isPaidOff
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (debt.isOverdue) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'OVERDUE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                          if (debt.isPaidOff) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'PAID OFF',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (debt.creditorName != null)
                        Text(
                          debt.creditorName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      debt.formattedBalance,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: debt.isPaidOff
                            ? Colors.green.shade400
                            : Colors.red.shade400,
                      ),
                    ),
                    if (debt.dueDate != null)
                      Text(
                        'Due: ${DateFormat('MMM d').format(debt.dueDate!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: debt.isOverdue
                              ? Colors.red.shade400
                              : (isDark ? Colors.white38 : Colors.black38),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress bar
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (progress / 100).clamp(0, 1),
                child: Container(
                  decoration: BoxDecoration(
                    color: debt.isPaidOff
                        ? Colors.green.shade400
                        : (isDark
                              ? const Color(0xFFCDAF56)
                              : Colors.blue.shade400),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${progress.toStringAsFixed(0)}% paid',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                Text(
                  'Original: ${debt.formattedOriginalAmount}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDebtDetailsScreen(BuildContext context, Debt debt) async {
    final didChange = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => DebtDetailsScreen(debtId: debt.id),
      ),
    );

    if (didChange == true) {
      ref.invalidate(allDebtsProvider);
      ref.invalidate(totalDebtByCurrencyProvider);
      ref.invalidate(totalDebtByCurrencyForDateProvider);
      ref.invalidate(debtStatisticsProvider);
    }
  }

  void _showAddDebtDialog(
    BuildContext context,
    bool isDark, {
    String? categoryId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddDebtSheet(
        isDark: isDark,
        initialCategoryId: categoryId,
        onSaved: () {
          ref.invalidate(allDebtsProvider);
          ref.invalidate(totalDebtByCurrencyProvider);
          ref.invalidate(totalDebtByCurrencyForDateProvider);
          ref.invalidate(debtStatisticsProvider);
        },
      ),
    );
  }

  void _showDebtCategoriesDialog(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DebtCategoriesSheet(
        isDark: isDark,
        onUpdate: () {
          ref.invalidate(allDebtCategoriesProvider);
        },
      ),
    );
  }
}

class _DebtCategorySection {
  final DebtCategory category;
  final List<Debt> debts;
  final String? addDebtCategoryId;

  const _DebtCategorySection({
    required this.category,
    required this.debts,
    required this.addDebtCategoryId,
  });
}

// ==================== ADD DEBT SHEET ====================

class _AddDebtSheet extends ConsumerStatefulWidget {
  final bool isDark;
  final String? initialCategoryId;
  final VoidCallback onSaved;

  const _AddDebtSheet({
    required this.isDark,
    this.initialCategoryId,
    required this.onSaved,
  });

  @override
  ConsumerState<_AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends ConsumerState<_AddDebtSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _creditorController = TextEditingController();
  final _notesController = TextEditingController();
  final _interestController = TextEditingController();
  final _minPaymentController = TextEditingController();

  String? _selectedCategoryId;
  String _selectedCurrency = FinanceSettingsService.fallbackCurrency;
  DateTime? _dueDate;
  bool _isLoading = false;
  bool _reminderEnabled = false;
  List<BillReminder> _reminders = [];

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _creditorController.dispose();
    _notesController.dispose();
    _interestController.dispose();
    _minPaymentController.dispose();
    super.dispose();
  }

  Widget _buildAddDebtReminderPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1A1D23) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_rounded, size: 20, color: AppColorSchemes.primaryGold),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Add reminders after saving the debt',
              style: TextStyle(
                fontSize: 14,
                color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDebt() async {
    if (_nameController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter name and amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.tryParse(_amountController.text) ?? 0;
      final interest = double.tryParse(_interestController.text);
      final minPayment = double.tryParse(_minPaymentController.text);

      final debt = Debt(
        name: _nameController.text,
        categoryId: _selectedCategoryId!,
        originalAmount: amount,
        creditorName: _creditorController.text.isEmpty
            ? null
            : _creditorController.text,
        interestRate: interest,
        minimumPayment: minPayment,
        dueDate: _dueDate,
        currency: _selectedCurrency,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        reminderEnabled: _reminderEnabled,
        remindersJson: BillReminder.encodeList(_reminders),
      );

      await ref.read(debtRepositoryProvider).createDebt(debt);
      
      // Sync with Notification Hub – do not block save if sync fails.
      try {
        final scheduler = FinanceNotificationScheduler();
        await scheduler.syncDebt(debt);
      } catch (e) {
        debugPrint('Notification sync error: $e');
      }
      
      widget.onSaved();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debt added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(allDebtCategoriesProvider);
    final defaultCurrencyAsync = ref.watch(defaultCurrencyProvider);

    // Set default currency when available
    defaultCurrencyAsync.whenData((currency) {
      if (_selectedCurrency == FinanceSettingsService.fallbackCurrency &&
          currency != FinanceSettingsService.fallbackCurrency) {
        _selectedCurrency = currency;
      }
    });

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E2128) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add New Debt',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: widget.isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  _buildTextField(
                    controller: _nameController,
                    label: 'Debt Name',
                    hint: 'e.g., Chase Credit Card',
                    icon: Icons.label_rounded,
                  ),
                  const SizedBox(height: 16),
                  // Category
                  Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  categoriesAsync.when(
                    data: (categories) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((cat) {
                        final isSelected = cat.id == _selectedCategoryId;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedCategoryId = cat.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? cat.color.withOpacity(0.2)
                                  : (widget.isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.black.withOpacity(0.05)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? cat.color
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  cat.icon ?? Icons.category_rounded,
                                  size: 18,
                                  color: cat.color,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  cat.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: widget.isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                  ),
                  const SizedBox(height: 16),
                  // Amount and Currency
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          controller: _amountController,
                          label: 'Amount Owed',
                          hint: '0.00',
                          icon: Icons.attach_money_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Currency',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: widget.isDark
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: widget.isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedCurrency,
                                  isExpanded: true,
                                  dropdownColor: widget.isDark
                                      ? const Color(0xFF2D3139)
                                      : Colors.white,
                                  items: FinanceSettingsService
                                      .supportedCurrencies
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(
                                            '${CurrencyUtils.getCurrencySymbol(c)} $c',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedCurrency = v!),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Creditor
                  _buildTextField(
                    controller: _creditorController,
                    label: 'Creditor (Optional)',
                    hint: 'Who do you owe?',
                    icon: Icons.person_rounded,
                  ),
                  const SizedBox(height: 16),
                  // Interest Rate and Min Payment
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _interestController,
                          label: 'Interest % (Optional)',
                          hint: '0.0',
                          icon: Icons.percent_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _minPaymentController,
                          label: 'Min Payment (Optional)',
                          hint: '0.00',
                          icon: Icons.payments_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Due Date
                  Text(
                    'Due Date (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 30),
                        ),
                      );
                      if (date != null) {
                        setState(() => _dueDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 20,
                            color: widget.isDark
                                ? Colors.white54
                                : Colors.black45,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _dueDate != null
                                ? DateFormat('MMMM d, yyyy').format(_dueDate!)
                                : 'Select due date',
                            style: TextStyle(
                              color: widget.isDark
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          if (_dueDate != null)
                            GestureDetector(
                              onTap: () => setState(() => _dueDate = null),
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: widget.isDark
                                    ? Colors.white38
                                    : Colors.black38,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Payment reminders
                  _buildAddDebtReminderPlaceholder(),
                  const SizedBox(height: 16),
                  // Notes
                  _buildTextField(
                    controller: _notesController,
                    label: 'Notes (Optional)',
                    hint: 'Additional details...',
                    icon: Icons.notes_rounded,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          // Save Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF1E2128) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveDebt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        'Add Debt',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: widget.isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: TextStyle(
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: widget.isDark ? Colors.white38 : Colors.black38,
            ),
            prefixIcon: Icon(
              icon,
              color: widget.isDark ? Colors.white54 : Colors.black45,
            ),
            filled: true,
            fillColor: widget.isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== DEBT DETAILS SCREEN ====================

class DebtDetailsScreen extends ConsumerStatefulWidget {
  final String debtId;

  const DebtDetailsScreen({super.key, required this.debtId});

  @override
  ConsumerState<DebtDetailsScreen> createState() => _DebtDetailsScreenState();
}

class _DebtDetailsScreenState extends ConsumerState<DebtDetailsScreen> {
  final _paymentController = TextEditingController();
  bool _isRecordingPayment = false;
  bool _isDeleting = false;

  void _invalidateDebtData() {
    ref.invalidate(allDebtsProvider);
    ref.invalidate(totalDebtByCurrencyProvider);
    ref.invalidate(totalDebtByCurrencyForDateProvider);
    ref.invalidate(debtStatisticsProvider);
  }

  Future<void> _recordPayment(Debt debt) async {
    final requestedAmount = double.tryParse(_paymentController.text);
    if (requestedAmount == null || requestedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid payment amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isRecordingPayment = true);
    try {
      final appliedAmount = requestedAmount > debt.currentBalance
          ? debt.currentBalance
          : requestedAmount;
      await ref
          .read(debtRepositoryProvider)
          .recordPayment(debt.id, requestedAmount);
      _invalidateDebtData();
      _paymentController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment of ${CurrencyUtils.getCurrencySymbol(debt.currency)}${appliedAmount.toStringAsFixed(2)} recorded',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecordingPayment = false);
    }
  }

  Future<void> _undoPaymentEntry(Debt debt, DebtPaymentEntry entry) async {
    try {
      final didUndo = await ref
          .read(debtRepositoryProvider)
          .undoPayment(debtId: debt.id, paymentId: entry.id);

      if (!didUndo) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to undo this payment'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      _invalidateDebtData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment ${CurrencyUtils.getCurrencySymbol(debt.currency)}${entry.amount.toStringAsFixed(2)} was undone',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _editPaymentEntry(Debt debt, DebtPaymentEntry entry) async {
    final controller = TextEditingController(
      text: entry.amount.toStringAsFixed(2),
    );

    final updatedAmount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Payment'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Amount',
            prefixText: '${CurrencyUtils.getCurrencySymbol(debt.currency)} ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text.trim());
              if (amount == null || amount <= 0) return;
              Navigator.of(context).pop(amount);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (updatedAmount == null) return;

    try {
      final didUpdate = await ref
          .read(debtRepositoryProvider)
          .updatePayment(
            debtId: debt.id,
            paymentId: entry.id,
            amount: updatedAmount,
          );

      if (!didUpdate) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to update this payment'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      _invalidateDebtData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment updated to ${CurrencyUtils.getCurrencySymbol(debt.currency)}${updatedAmount.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteDebt(Debt debt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Debt?'),
        content: Text('Are you sure you want to delete "${debt.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      try {
        await FinanceNotificationScheduler().cancelDebtNotifications(debt.id);
      } catch (_) {}
      await ref.read(debtRepositoryProvider).deleteDebt(debt.id);
      _invalidateDebtData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debt deleted'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _showEditDebtSheet(BuildContext context, Debt debt, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditDebtSheet(
        debt: debt,
        isDark: isDark,
        onSaved: _invalidateDebtData,
      ),
    );
  }

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final debtsAsync = ref.watch(allDebtsProvider);
    final categoriesAsync = ref.watch(allDebtCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Debt Details')),
      body: debtsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (debts) {
          final debtIndex = debts.indexWhere((d) => d.id == widget.debtId);
          if (debtIndex == -1) {
            return const Center(child: Text('Debt not found'));
          }
          final debt = debts[debtIndex];

          final categoryName = categoriesAsync.maybeWhen(
            data: (categories) {
              for (final category in categories) {
                if (category.id == debt.categoryId) return category.name;
              }
              return null;
            },
            orElse: () => null,
          );
          final paymentHistory = debt.paymentHistory;

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final dueDateOnly = debt.dueDate == null
              ? null
              : DateTime(
                  debt.dueDate!.year,
                  debt.dueDate!.month,
                  debt.dueDate!.day,
                );
          final daysUntilDue = dueDateOnly?.difference(today).inDays;
          final hasDueDatePlan = !debt.isPaidOff && daysUntilDue != null;
          final plannedDays = hasDueDatePlan
              ? (daysUntilDue <= 0 ? 1 : daysUntilDue)
              : null;
          final requiredDailyPayment = plannedDays == null || plannedDays <= 0
              ? null
              : debt.currentBalance / plannedDays;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: debt.color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              debt.icon ?? Icons.account_balance_rounded,
                              color: debt.color,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  debt.name,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                if (debt.creditorName != null)
                                  Text(
                                    debt.creditorName!,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black54,
                                    ),
                                  ),
                                if (categoryName != null)
                                  Text(
                                    categoryName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black45,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Current Balance',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          Text(
                            debt.formattedBalance,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: debt.isPaidOff
                                  ? Colors.green.shade400
                                  : Colors.red.shade400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Original Amount',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black45,
                            ),
                          ),
                          Text(
                            debt.formattedOriginalAmount,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      if (debt.dueDate != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Due Date',
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black45,
                              ),
                            ),
                            Text(
                              DateFormat('MMM d, yyyy').format(debt.dueDate!),
                              style: TextStyle(
                                color: debt.isOverdue
                                    ? Colors.red.shade400
                                    : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      Container(
                        height: 8,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.black.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (debt.paymentProgress / 100).clamp(0, 1),
                          child: Container(
                            decoration: BoxDecoration(
                              color: debt.isPaidOff
                                  ? Colors.green.shade400
                                  : const Color(0xFFCDAF56),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${debt.paymentProgress.toStringAsFixed(1)}% paid off',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (hasDueDatePlan) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildInsightTile(
                          isDark: isDark,
                          icon: Icons.timelapse_rounded,
                          title: 'Due Countdown',
                          value: daysUntilDue < 0
                              ? '${daysUntilDue.abs()} day${daysUntilDue.abs() == 1 ? '' : 's'} overdue'
                              : (daysUntilDue == 0
                                    ? 'Due today'
                                    : '$daysUntilDue day${daysUntilDue == 1 ? '' : 's'} left'),
                          valueColor: daysUntilDue < 0
                              ? Colors.red.shade400
                              : (daysUntilDue == 0
                                    ? Colors.orange.shade400
                                    : (isDark ? Colors.white : Colors.black87)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildInsightTile(
                          isDark: isDark,
                          icon: Icons.savings_rounded,
                          title: 'Target / Day',
                          value:
                              '${CurrencyUtils.getCurrencySymbol(debt.currency)}${(requiredDailyPayment ?? debt.currentBalance).toStringAsFixed(2)}',
                          subtitle: daysUntilDue <= 0
                              ? 'Pay now to clear'
                              : 'to clear by due date',
                          valueColor: const Color(0xFFCDAF56),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                if (!debt.isPaidOff) ...[
                  Text(
                    'Make Payment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _paymentController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter amount',
                            prefixText:
                                '${CurrencyUtils.getCurrencySymbol(debt.currency)} ',
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _isRecordingPayment
                            ? null
                            : () => _recordPayment(debt),
                        icon: _isRecordingPayment
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.payments_rounded),
                        label: const Text('Pay'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          _showEditDebtSheet(context, debt, isDark),
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit Debt'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isDeleting ? null : () => _deleteDebt(debt),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red.shade400,
                      ),
                      label: Text(
                        'Delete Debt',
                        style: TextStyle(color: Colors.red.shade400),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Payment History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: paymentHistory.isEmpty
                      ? Text(
                          'No payments logged yet.',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        )
                      : Column(
                          children: [
                            for (final paymentEntry
                                in paymentHistory.asMap().entries) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: Colors.green.shade400,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat(
                                            'MMM d, yyyy - h:mm a',
                                          ).format(paymentEntry.value.paidAt),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Balance after: ${CurrencyUtils.getCurrencySymbol(debt.currency)}${paymentEntry.value.balanceAfter.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.black54,
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
                                        '+${CurrencyUtils.getCurrencySymbol(debt.currency)}${paymentEntry.value.amount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.green.shade400,
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: Icon(
                                          Icons.more_horiz_rounded,
                                          size: 18,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black54,
                                        ),
                                        padding: EdgeInsets.zero,
                                        itemBuilder: (_) => const [
                                          PopupMenuItem<String>(
                                            value: 'edit',
                                            child: Text('Edit Amount'),
                                          ),
                                          PopupMenuItem<String>(
                                            value: 'undo',
                                            child: Text('Undo Payment'),
                                          ),
                                        ],
                                        onSelected: (action) {
                                          if (action == 'edit') {
                                            _editPaymentEntry(
                                              debt,
                                              paymentEntry.value,
                                            );
                                          } else if (action == 'undo') {
                                            _undoPaymentEntry(
                                              debt,
                                              paymentEntry.value,
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (paymentEntry.key !=
                                  paymentHistory.length - 1) ...[
                                const SizedBox(height: 10),
                                Divider(
                                  height: 1,
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.black.withOpacity(0.08),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ],
                          ],
                        ),
                ),
                if (debt.notes != null && debt.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Notes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      debt.notes!,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInsightTile({
    required bool isDark,
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: valueColor ?? (isDark ? Colors.white : Colors.black87),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ==================== DEBT CATEGORIES SHEET ====================

class _DebtCategoriesSheet extends ConsumerStatefulWidget {
  final bool isDark;
  final VoidCallback onUpdate;

  const _DebtCategoriesSheet({required this.isDark, required this.onUpdate});

  @override
  ConsumerState<_DebtCategoriesSheet> createState() =>
      _DebtCategoriesSheetState();
}

class _DebtCategoriesSheetState extends ConsumerState<_DebtCategoriesSheet> {
  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(allDebtCategoriesProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E2128) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Debt Categories',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _showAddEditCategoryDialog(context),
                      icon: Icon(
                        Icons.add_circle_outline_rounded,
                        color: widget.isDark
                            ? const Color(0xFFCDAF56)
                            : Colors.blue,
                      ),
                      tooltip: 'Add Category',
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: widget.isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Categories list
          Expanded(
            child: categoriesAsync.when(
              data: (categories) => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cat.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            cat.icon ?? Icons.category_rounded,
                            color: cat.color,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: widget.isDark
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              if (cat.description != null)
                                Text(
                                  cat.description!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: widget.isDark
                                        ? Colors.white54
                                        : Colors.black45,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _showAddEditCategoryDialog(
                                context,
                                category: cat,
                              ),
                              icon: Icon(
                                Icons.edit_rounded,
                                size: 18,
                                color: widget.isDark
                                    ? Colors.white38
                                    : Colors.black38,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              onPressed: () =>
                                  _confirmDeleteCategory(context, cat),
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: Colors.red.shade400,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEditCategoryDialog(
    BuildContext context, {
    DebtCategory? category,
  }) {
    showDialog(
      context: context,
      builder: (context) => _AddEditDebtCategoryDialog(
        category: category,
        isDark: widget.isDark,
        onSaved: () {
          ref.invalidate(allDebtCategoriesProvider);
          widget.onUpdate();
        },
      ),
    );
  }

  Future<void> _confirmDeleteCategory(
    BuildContext context,
    DebtCategory category,
  ) async {
    // Check if category has debts
    final debtsAsync = ref.read(allDebtsProvider);
    final hasDebts =
        debtsAsync.value?.any((d) => d.categoryId == category.id) ?? false;

    if (hasDebts) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot delete category with active debts. Move or delete them first.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref
            .read(debtCategoryRepositoryProvider)
            .deleteCategory(category.id);
        ref.invalidate(allDebtCategoriesProvider);
        widget.onUpdate();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

// ==================== ADD/EDIT DEBT CATEGORY DIALOG ====================

class _AddEditDebtCategoryDialog extends StatefulWidget {
  final DebtCategory? category;
  final bool isDark;
  final VoidCallback onSaved;

  const _AddEditDebtCategoryDialog({
    this.category,
    required this.isDark,
    required this.onSaved,
  });

  @override
  State<_AddEditDebtCategoryDialog> createState() =>
      _AddEditDebtCategoryDialogState();
}

class _AddEditDebtCategoryDialogState
    extends State<_AddEditDebtCategoryDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  late IconData _selectedIcon;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _descriptionController.text = widget.category!.description ?? '';
      _selectedIcon = widget.category!.icon ?? Icons.category_rounded;
      _selectedColor = widget.category!.color;
    } else {
      _selectedIcon = Icons.category_rounded;
      _selectedColor = Colors.blue;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1E2128) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: widget.isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                isEditing ? 'Edit Category' : 'New Category',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              // Form fields
              _buildTextField(
                controller: _nameController,
                label: 'Category Name',
                hint: 'e.g., Personal Loan',
                icon: Icons.label_outline_rounded,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _descriptionController,
                label: 'Description (Optional)',
                hint: 'Add a short note...',
                icon: Icons.notes_rounded,
              ),
              const SizedBox(height: 24),
              // Icon & Color Selection
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Icon',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: widget.isDark
                                ? Colors.white54
                                : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: _showIconPicker,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: widget.isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: widget.isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.black.withOpacity(0.05),
                              ),
                            ),
                            child: Icon(
                              _selectedIcon,
                              color: _selectedColor,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Color',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: widget.isDark
                                ? Colors.white54
                                : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: _showColorPicker,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: widget.isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: widget.isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.black.withOpacity(0.05),
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: _selectedColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _selectedColor.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Actions
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: widget.isDark
                              ? Colors.white60
                              : Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCDAF56),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: TextStyle(
            color: widget.isDark ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: widget.isDark ? Colors.white24 : Colors.black26,
              fontSize: 15,
            ),
            prefixIcon: Icon(
              icon,
              color: widget.isDark ? Colors.white38 : Colors.black38,
              size: 20,
            ),
            filled: true,
            fillColor: widget.isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
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

  Future<void> _showIconPicker() async {
    final icon = await showDialog<IconData>(
      context: context,
      builder: (context) =>
          IconPickerWidget(selectedIcon: _selectedIcon, isDark: widget.isDark),
    );
    if (icon != null) {
      setState(() => _selectedIcon = icon);
    }
  }

  Future<void> _showColorPicker() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => ColorPickerWidget(
        selectedColor: _selectedColor,
        isDark: widget.isDark,
      ),
    );
    if (color != null) {
      setState(() => _selectedColor = color);
    }
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty) return;

    final container = ProviderScope.containerOf(context);
    final repo = container.read(debtCategoryRepositoryProvider);

    if (widget.category != null) {
      final updated = widget.category!.copyWith(
        name: _nameController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        iconCodePoint: _selectedIcon.codePoint,
        iconFontFamily: _selectedIcon.fontFamily,
        iconFontPackage: _selectedIcon.fontPackage,
        colorValue: _selectedColor.value,
      );
      await repo.updateCategory(updated);
    } else {
      final newCat = DebtCategory(
        name: _nameController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        icon: _selectedIcon,
        colorValue: _selectedColor.value,
      );
      await repo.createCategory(newCat);
    }

    widget.onSaved();
    if (mounted) Navigator.of(context).pop();
  }
}

// ==================== EDIT DEBT SHEET ====================

class _EditDebtSheet extends ConsumerStatefulWidget {
  final Debt debt;
  final bool isDark;
  final VoidCallback onSaved;

  const _EditDebtSheet({
    required this.debt,
    required this.isDark,
    required this.onSaved,
  });

  @override
  ConsumerState<_EditDebtSheet> createState() => _EditDebtSheetState();
}

class _EditDebtSheetState extends ConsumerState<_EditDebtSheet> {
  late TextEditingController _nameController;
  late TextEditingController _currentBalanceController;
  late TextEditingController _originalAmountController;
  late TextEditingController _creditorController;
  late TextEditingController _notesController;
  late TextEditingController _interestController;
  late TextEditingController _minPaymentController;

  late String _selectedCategoryId;
  late String _selectedCurrency;
  DateTime? _dueDate;
  bool _isLoading = false;
  late bool _reminderEnabled;
  late List<BillReminder> _reminders;

  @override
  void initState() {
    super.initState();
    final debt = widget.debt;
    _nameController = TextEditingController(text: debt.name);
    _currentBalanceController = TextEditingController(
      text: debt.currentBalance.toStringAsFixed(2),
    );
    _originalAmountController = TextEditingController(
      text: debt.originalAmount.toStringAsFixed(2),
    );
    _creditorController = TextEditingController(text: debt.creditorName ?? '');
    _notesController = TextEditingController(text: debt.notes ?? '');
    _interestController = TextEditingController(
      text: debt.interestRate?.toString() ?? '',
    );
    _minPaymentController = TextEditingController(
      text: debt.minimumPayment?.toString() ?? '',
    );
    _selectedCategoryId = debt.categoryId;
    _selectedCurrency = debt.currency;
    _dueDate = debt.dueDate;
    _reminderEnabled = debt.reminderEnabled;
    _reminders = List<BillReminder>.from(debt.reminders);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentBalanceController.dispose();
    _originalAmountController.dispose();
    _creditorController.dispose();
    _notesController.dispose();
    _interestController.dispose();
    _minPaymentController.dispose();
    super.dispose();
  }

  Future<void> _saveDebt() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentBalance =
          double.tryParse(_currentBalanceController.text) ?? 0;
      final originalAmount =
          double.tryParse(_originalAmountController.text) ?? 0;
      final interest = double.tryParse(_interestController.text);
      final minPayment = double.tryParse(_minPaymentController.text);

      final updatedDebt = widget.debt.copyWith(
        name: _nameController.text,
        categoryId: _selectedCategoryId,
        originalAmount: originalAmount,
        currentBalance: currentBalance,
        creditorName: _creditorController.text.isEmpty
            ? null
            : _creditorController.text,
        interestRate: interest,
        minimumPayment: minPayment,
        dueDate: _dueDate,
        currency: _selectedCurrency,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        status: currentBalance <= 0 ? 'paidOff' : 'active',
        reminderEnabled: _reminderEnabled,
        remindersJson: BillReminder.encodeList(_reminders),
      );

      await ref.read(debtRepositoryProvider).updateDebt(updatedDebt);
      
      // Sync with Notification Hub – do not block save if sync fails.
      try {
        final scheduler = FinanceNotificationScheduler();
        await scheduler.syncDebt(updatedDebt);
      } catch (e) {
        debugPrint('Notification sync error: $e');
      }
      
      widget.onSaved();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debt updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(allDebtCategoriesProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E2128) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Debt',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: widget.isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  _buildTextField(
                    controller: _nameController,
                    label: 'Debt Name',
                    hint: 'e.g., Chase Credit Card',
                    icon: Icons.label_rounded,
                  ),
                  const SizedBox(height: 16),
                  // Category
                  Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  categoriesAsync.when(
                    data: (categories) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((cat) {
                        final isSelected = cat.id == _selectedCategoryId;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedCategoryId = cat.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? cat.color.withOpacity(0.2)
                                  : (widget.isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.black.withOpacity(0.05)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? cat.color
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  cat.icon ?? Icons.category_rounded,
                                  size: 18,
                                  color: cat.color,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  cat.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: widget.isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                  ),
                  const SizedBox(height: 16),
                  // Current Balance and Original Amount
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _currentBalanceController,
                          label: 'Current Balance',
                          hint: '0.00',
                          icon: Icons.account_balance_wallet_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _originalAmountController,
                          label: 'Original Amount',
                          hint: '0.00',
                          icon: Icons.attach_money_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Currency
                  Text(
                    'Currency',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCurrency,
                        isExpanded: true,
                        dropdownColor: widget.isDark
                            ? const Color(0xFF2D3139)
                            : Colors.white,
                        items: FinanceSettingsService.supportedCurrencies
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  '${CurrencyUtils.getCurrencySymbol(c)} $c',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedCurrency = v!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Creditor
                  _buildTextField(
                    controller: _creditorController,
                    label: 'Creditor (Optional)',
                    hint: 'Who do you owe?',
                    icon: Icons.person_rounded,
                  ),
                  const SizedBox(height: 16),
                  // Interest Rate and Min Payment
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _interestController,
                          label: 'Interest % (Optional)',
                          hint: '0.0',
                          icon: Icons.percent_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _minPaymentController,
                          label: 'Min Payment (Optional)',
                          hint: '0.00',
                          icon: Icons.payments_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Due Date
                  Text(
                    'Due Date (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 30),
                        ),
                      );
                      if (date != null) {
                        setState(() => _dueDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 20,
                            color: widget.isDark
                                ? Colors.white54
                                : Colors.black45,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _dueDate != null
                                ? DateFormat('MMMM d, yyyy').format(_dueDate!)
                                : 'Select due date',
                            style: TextStyle(
                              color: widget.isDark
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          if (_dueDate != null)
                            GestureDetector(
                              onTap: () => setState(() => _dueDate = null),
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: widget.isDark
                                    ? Colors.white38
                                    : Colors.black38,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Payment reminders
                  UniversalReminderSection(
                    creatorContext: FinanceNotificationCreatorContext.forDebt(
                      debtId: widget.debt.id,
                      debtorName: widget.debt.name,
                    ),
                    isDark: widget.isDark,
                  ),
                  const SizedBox(height: 16),
                  // Notes
                  _buildTextField(
                    controller: _notesController,
                    label: 'Notes (Optional)',
                    hint: 'Additional details...',
                    icon: Icons.notes_rounded,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          // Save Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF1E2128) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveDebt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCDAF56),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: widget.isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: TextStyle(
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: widget.isDark ? Colors.white38 : Colors.black38,
            ),
            prefixIcon: Icon(
              icon,
              color: widget.isDark ? Colors.white54 : Colors.black45,
            ),
            filled: true,
            fillColor: widget.isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

/// Filter Sheet Widget
class _FilterSheet extends StatefulWidget {
  final bool isDark;
  final List<DebtCategory> categories;
  final Set<String> selectedCategoryIds;
  final DebtStatusFilter statusFilter;
  final Function(Set<String>, DebtStatusFilter) onApply;

  const _FilterSheet({
    required this.isDark,
    required this.categories,
    required this.selectedCategoryIds,
    required this.statusFilter,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<String> _selectedCategories;
  late DebtStatusFilter _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedCategories = Set.from(widget.selectedCategoryIds);
    _selectedStatus = widget.statusFilter;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E2128) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter Debts',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategories = {};
                      _selectedStatus = DebtStatusFilter.all;
                    });
                  },
                  child: const Text(
                    'Reset',
                    style: TextStyle(color: Color(0xFFCDAF56)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Filter
                  Text(
                    'STATUS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? Colors.white54 : Colors.black45,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: DebtStatusFilter.values.map((status) {
                      final isSelected = _selectedStatus == status;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedStatus = status),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFCDAF56).withOpacity(0.15)
                                : (widget.isDark
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.black.withOpacity(0.03)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFCDAF56)
                                  : (widget.isDark
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.black.withOpacity(0.05)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getStatusIcon(status),
                                size: 16,
                                color: isSelected
                                    ? const Color(0xFFCDAF56)
                                    : (widget.isDark
                                          ? Colors.white60
                                          : Colors.black54),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _getStatusLabel(status),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? const Color(0xFFCDAF56)
                                      : (widget.isDark
                                            ? Colors.white70
                                            : Colors.black54),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  // Category Filter
                  Text(
                    'CATEGORIES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? Colors.white54 : Colors.black45,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.categories.isEmpty)
                    Text(
                      'No categories available',
                      style: TextStyle(
                        color: widget.isDark ? Colors.white54 : Colors.black45,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.categories.map((category) {
                        final isSelected = _selectedCategories.contains(
                          category.id,
                        );
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedCategories.remove(category.id);
                              } else {
                                _selectedCategories.add(category.id);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? category.color.withOpacity(0.15)
                                  : (widget.isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.black.withOpacity(0.03)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? category.color
                                    : (widget.isDark
                                          ? Colors.white.withOpacity(0.1)
                                          : Colors.black.withOpacity(0.05)),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  category.icon ?? Icons.category_rounded,
                                  size: 16,
                                  color: isSelected
                                      ? category.color
                                      : (widget.isDark
                                            ? Colors.white60
                                            : Colors.black54),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  category.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? category.color
                                        : (widget.isDark
                                              ? Colors.white70
                                              : Colors.black54),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: category.color,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          // Apply Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF1E2128) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: widget.isDark
                      ? Colors.white10
                      : Colors.black.withOpacity(0.05),
                ),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    widget.onApply(_selectedCategories, _selectedStatus),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCDAF56),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(DebtStatusFilter status) {
    switch (status) {
      case DebtStatusFilter.all:
        return Icons.all_inclusive_rounded;
      case DebtStatusFilter.active:
        return Icons.pending_rounded;
      case DebtStatusFilter.overdue:
        return Icons.warning_amber_rounded;
      case DebtStatusFilter.paidOff:
        return Icons.check_circle_rounded;
    }
  }

  String _getStatusLabel(DebtStatusFilter status) {
    switch (status) {
      case DebtStatusFilter.all:
        return 'All';
      case DebtStatusFilter.active:
        return 'Active';
      case DebtStatusFilter.overdue:
        return 'Overdue';
      case DebtStatusFilter.paidOff:
        return 'Paid Off';
    }
  }
}

/// Sort Sheet Widget
class _SortSheet extends StatefulWidget {
  final bool isDark;
  final DebtSortBy currentSortBy;
  final SortDirection currentDirection;
  final Function(DebtSortBy, SortDirection) onApply;

  const _SortSheet({
    required this.isDark,
    required this.currentSortBy,
    required this.currentDirection,
    required this.onApply,
  });

  @override
  State<_SortSheet> createState() => _SortSheetState();
}

class _SortSheetState extends State<_SortSheet> {
  late DebtSortBy _sortBy;
  late SortDirection _direction;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.currentSortBy;
    _direction = widget.currentDirection;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E2128) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'Sort By',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Sort Options
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: DebtSortBy.values.map((sortBy) {
                  final isSelected = _sortBy == sortBy;
                  return ListTile(
                    onTap: () {
                      setState(() {
                        if (_sortBy == sortBy) {
                          // Toggle direction if same sort is tapped
                          _direction = _direction == SortDirection.ascending
                              ? SortDirection.descending
                              : SortDirection.ascending;
                        } else {
                          _sortBy = sortBy;
                          // Default direction based on sort type
                          _direction = sortBy == DebtSortBy.amount
                              ? SortDirection.descending
                              : SortDirection.ascending;
                        }
                      });
                    },
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFCDAF56).withOpacity(0.15)
                            : (widget.isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.03)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getSortIcon(sortBy),
                        size: 20,
                        color: isSelected
                            ? const Color(0xFFCDAF56)
                            : (widget.isDark ? Colors.white60 : Colors.black45),
                      ),
                    ),
                    title: Text(
                      _getSortLabel(sortBy),
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFFCDAF56)
                            : (widget.isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    trailing: isSelected
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _direction == SortDirection.ascending
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                size: 18,
                                color: const Color(0xFFCDAF56),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _direction == SortDirection.ascending
                                    ? (sortBy == DebtSortBy.amount
                                          ? 'Low to High'
                                          : (sortBy == DebtSortBy.name
                                                ? 'A to Z'
                                                : 'Oldest'))
                                    : (sortBy == DebtSortBy.amount
                                          ? 'High to Low'
                                          : (sortBy == DebtSortBy.name
                                                ? 'Z to A'
                                                : 'Newest')),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: widget.isDark
                                      ? Colors.white54
                                      : Colors.black45,
                                ),
                              ),
                            ],
                          )
                        : null,
                  );
                }).toList(),
              ),
            ),
          ),
          // Apply Button
          Container(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: 24,
              top: 12,
            ),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF1E2128) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: widget.isDark
                      ? Colors.white10
                      : Colors.black.withOpacity(0.05),
                ),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => widget.onApply(_sortBy, _direction),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCDAF56),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Apply Sort',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSortIcon(DebtSortBy sortBy) {
    switch (sortBy) {
      case DebtSortBy.amount:
        return Icons.attach_money_rounded;
      case DebtSortBy.dueDate:
        return Icons.calendar_today_rounded;
      case DebtSortBy.name:
        return Icons.sort_by_alpha_rounded;
      case DebtSortBy.dateAdded:
        return Icons.schedule_rounded;
    }
  }

  String _getSortLabel(DebtSortBy sortBy) {
    switch (sortBy) {
      case DebtSortBy.amount:
        return 'Amount';
      case DebtSortBy.dueDate:
        return 'Due Date';
      case DebtSortBy.name:
        return 'Name';
      case DebtSortBy.dateAdded:
        return 'Date Added';
    }
  }
}

/// Professional Bank-Level Debt Calculator with Multi-Select
class _DebtCalculatorSheet extends StatefulWidget {
  final bool isDark;
  final List<Debt> debts;

  const _DebtCalculatorSheet({required this.isDark, required this.debts});

  @override
  State<_DebtCalculatorSheet> createState() => _DebtCalculatorSheetState();
}

enum CalculatorMode { plan, immediate }

enum CalculatorFrequency { daily, weekly, biWeekly, monthly }

enum PaymentStrategy { avalanche, snowball, proportional }

class _DebtCalculatorSheetState extends State<_DebtCalculatorSheet> {
  // Multi-select: Set of debt IDs. Empty = all debts
  Set<String> _selectedDebtIds = {};
  final _paymentController = TextEditingController();
  final _intervalController = TextEditingController(text: '1');

  CalculatorMode _mode = CalculatorMode.plan;
  CalculatorFrequency _frequency = CalculatorFrequency.monthly;
  PaymentStrategy _strategy = PaymentStrategy.avalanche;

  // Currency warning
  bool _hasMixedCurrencies = false;
  String _primaryCurrency = FinanceSettingsService.fallbackCurrency;

  // Results
  int? _totalOccurrences;
  double _totalInterestPaid = 0;
  DateTime? _payoffDate;
  double _totalPaidTotal = 0;
  double _remainingBalance = 0;
  double _totalStartingBalance = 0;
  List<_DebtPayoffResult> _debtResults = [];

  List<Debt> get _selectedDebts {
    if (_selectedDebtIds.isEmpty) return widget.debts;
    return widget.debts.where((d) => _selectedDebtIds.contains(d.id)).toList();
  }

  @override
  void initState() {
    super.initState();
    _checkCurrencies();
    _calculateResults();
  }

  @override
  void dispose() {
    _paymentController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  void _checkCurrencies() {
    final currencies = widget.debts.map((d) => d.currency).toSet();
    _hasMixedCurrencies = currencies.length > 1;
    _primaryCurrency = widget.debts.isNotEmpty
        ? widget.debts.first.currency
        : FinanceSettingsService.fallbackCurrency;

    // Filter selected debts to match primary currency if mixed
    if (_hasMixedCurrencies && _selectedDebtIds.isEmpty) {
      // Auto-select first currency group
      _selectedDebtIds = widget.debts
          .where((d) => d.currency == _primaryCurrency)
          .map((d) => d.id)
          .toSet();
    }
  }

  void _toggleDebtSelection(String debtId) {
    setState(() {
      if (_selectedDebtIds.contains(debtId)) {
        _selectedDebtIds.remove(debtId);
      } else {
        // Check currency compatibility
        final debt = widget.debts.firstWhere((d) => d.id == debtId);
        if (_selectedDebtIds.isEmpty) {
          _primaryCurrency = debt.currency;
          _selectedDebtIds.add(debtId);
        } else {
          final currentCurrency = widget.debts
              .firstWhere((d) => _selectedDebtIds.contains(d.id))
              .currency;
          if (debt.currency == currentCurrency) {
            _selectedDebtIds.add(debtId);
          } else {
            // Show currency mismatch warning
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Cannot mix ${debt.currency} with $currentCurrency debts',
                ),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
        }
      }
    });
    _calculateResults();
  }

  void _selectAll() {
    setState(() {
      // Select all debts with the same currency as the first
      _selectedDebtIds = widget.debts
          .where((d) => d.currency == _primaryCurrency)
          .map((d) => d.id)
          .toSet();
    });
    _calculateResults();
  }

  void _clearSelection() {
    setState(() {
      _selectedDebtIds = {};
    });
    _calculateResults();
  }

  void _calculateResults() {
    final payment = double.tryParse(_paymentController.text) ?? 0;
    final interval = int.tryParse(_intervalController.text) ?? 1;
    final debtsToCalc = _selectedDebts;

    if (debtsToCalc.isEmpty) {
      setState(() {
        _totalOccurrences = null;
        _debtResults = [];
      });
      return;
    }

    _primaryCurrency = debtsToCalc.first.currency;
    _totalStartingBalance = debtsToCalc.fold(
      0.0,
      (sum, d) => sum + d.currentBalance,
    );

    if (payment <= 0) {
      setState(() {
        _totalOccurrences = null;
        _totalInterestPaid = 0;
        _payoffDate = null;
        _totalPaidTotal = 0;
        _remainingBalance = _totalStartingBalance;
        _debtResults = [];
      });
      return;
    }

    if (_mode == CalculatorMode.immediate) {
      _calculateImmediate(payment, debtsToCalc);
      return;
    }

    // Professional Multi-Debt Simulation with Payment Strategies
    _calculatePlanWithStrategy(payment, interval, debtsToCalc);
  }

  void _calculateImmediate(double payment, List<Debt> debts) {
    double remaining = payment;
    final results = <_DebtPayoffResult>[];
    double totalRemaining = 0;

    // Sort debts by strategy for payment allocation
    final sortedDebts = _getSortedDebts(debts);

    for (final debt in sortedDebts) {
      final allocated = math.min(remaining, debt.currentBalance);
      final newBalance = debt.currentBalance - allocated;
      remaining -= allocated;
      totalRemaining += newBalance;

      results.add(
        _DebtPayoffResult(
          debtName: debt.name,
          originalBalance: debt.currentBalance,
          finalBalance: newBalance,
          interestPaid: 0,
          totalPaid: allocated,
          payoffOccurrence: newBalance <= 0 ? 1 : null,
          color: debt.color,
        ),
      );
    }

    setState(() {
      _remainingBalance = totalRemaining;
      _totalOccurrences = 1;
      _totalPaidTotal = payment - remaining;
      _totalInterestPaid = 0;
      _payoffDate = DateTime.now();
      _debtResults = results;
    });
  }

  void _calculatePlanWithStrategy(
    double paymentPerOccurrence,
    int timesPerPeriod,
    List<Debt> debts,
  ) {
    final periodPayment = paymentPerOccurrence * timesPerPeriod;

    // Create working copies of each debt
    final workingDebts = debts
        .map(
          (d) => _WorkingDebt(
            id: d.id,
            name: d.name,
            balance: d.currentBalance,
            apr: d.interestRate ?? 0,
            color: d.color,
            originalBalance: d.currentBalance,
          ),
        )
        .toList();

    int daysInPeriod;
    switch (_frequency) {
      case CalculatorFrequency.daily:
        daysInPeriod = 1;
        break;
      case CalculatorFrequency.weekly:
        daysInPeriod = 7;
        break;
      case CalculatorFrequency.biWeekly:
        daysInPeriod = 14;
        break;
      case CalculatorFrequency.monthly:
        daysInPeriod = 30;
        break;
    }

    int occurrences = 0;
    DateTime currentDate = DateTime.now();
    double totalInterest = 0;

    // Check if payment can ever pay off (must exceed total minimum interest)
    double totalMinInterestPerPeriod = 0;
    for (final wd in workingDebts) {
      totalMinInterestPerPeriod +=
          wd.balance * (wd.apr / 100 / 365) * daysInPeriod;
    }

    if (periodPayment <= totalMinInterestPerPeriod &&
        totalMinInterestPerPeriod > 0) {
      setState(() {
        _totalOccurrences = -1;
        _totalInterestPaid = 0;
        _payoffDate = null;
        _debtResults = [];
      });
      return;
    }

    // Main simulation loop (max 50 years)
    final maxOccurrences = 50 * 365 ~/ daysInPeriod;

    while (workingDebts.any((d) => d.balance > 0.01) &&
        occurrences < maxOccurrences) {
      occurrences++;
      currentDate = currentDate.add(Duration(days: daysInPeriod));

      // Step 1: Accrue interest on all debts (daily compounding converted to period)
      for (final wd in workingDebts) {
        if (wd.balance > 0) {
          final periodInterest =
              wd.balance * (wd.apr / 100 / 365) * daysInPeriod;
          wd.balance += periodInterest;
          wd.interestAccrued += periodInterest;
          totalInterest += periodInterest;
        }
      }

      // Step 2: Allocate payment according to strategy
      double remainingPayment = periodPayment;
      final sortedWorking = _getSortedWorkingDebts(workingDebts);

      for (final wd in sortedWorking) {
        if (wd.balance <= 0 || remainingPayment <= 0) continue;

        final paymentToThis = math.min(remainingPayment, wd.balance);
        wd.balance -= paymentToThis;
        wd.totalPaid += paymentToThis;
        remainingPayment -= paymentToThis;

        if (wd.balance <= 0.01 && wd.payoffOccurrence == null) {
          wd.payoffOccurrence = occurrences;
          wd.balance = 0;
        }
      }
    }

    // Build results
    final results = workingDebts
        .map(
          (wd) => _DebtPayoffResult(
            debtName: wd.name,
            originalBalance: wd.originalBalance,
            finalBalance: wd.balance,
            interestPaid: wd.interestAccrued,
            totalPaid: wd.totalPaid,
            payoffOccurrence: wd.payoffOccurrence,
            color: wd.color,
          ),
        )
        .toList();

    setState(() {
      _totalOccurrences = occurrences;
      _totalInterestPaid = totalInterest;
      _totalPaidTotal = _totalStartingBalance + totalInterest;
      _payoffDate = currentDate;
      _remainingBalance = workingDebts.fold(0.0, (sum, d) => sum + d.balance);
      _debtResults = results;
    });
  }

  List<Debt> _getSortedDebts(List<Debt> debts) {
    final sorted = List<Debt>.from(debts);
    switch (_strategy) {
      case PaymentStrategy.avalanche:
        sorted.sort(
          (a, b) => (b.interestRate ?? 0).compareTo(a.interestRate ?? 0),
        );
        break;
      case PaymentStrategy.snowball:
        sorted.sort((a, b) => a.currentBalance.compareTo(b.currentBalance));
        break;
      case PaymentStrategy.proportional:
        // Keep original order for proportional
        break;
    }
    return sorted;
  }

  List<_WorkingDebt> _getSortedWorkingDebts(List<_WorkingDebt> debts) {
    final sorted = debts.where((d) => d.balance > 0).toList();
    switch (_strategy) {
      case PaymentStrategy.avalanche:
        sorted.sort((a, b) => b.apr.compareTo(a.apr));
        break;
      case PaymentStrategy.snowball:
        sorted.sort((a, b) => a.balance.compareTo(b.balance));
        break;
      case PaymentStrategy.proportional:
        // For proportional, we'd split payment, but we simplify to sequential here
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E2128) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCDAF56).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.precision_manufacturing_rounded,
                    color: Color(0xFFCDAF56),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Debt Simulator Pro',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'Bank-level precision calculations',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.isDark
                              ? Colors.white54
                              : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: widget.isDark ? Colors.white54 : Colors.black45,
                ),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Multi-Select Debt Chips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SELECT DEBTS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: widget.isDark
                              ? Colors.white38
                              : Colors.black38,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _selectAll,
                            child: Text(
                              'All',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFCDAF56),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _clearSelection,
                            child: Text(
                              'Clear',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: widget.isDark
                                    ? Colors.white54
                                    : Colors.black45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.debts.map((debt) {
                      final isSelected =
                          _selectedDebtIds.isEmpty ||
                          _selectedDebtIds.contains(debt.id);
                      final isDisabled =
                          _selectedDebtIds.isNotEmpty &&
                          !_selectedDebtIds.contains(debt.id) &&
                          debt.currency != _primaryCurrency;

                      return GestureDetector(
                        onTap: isDisabled
                            ? null
                            : () => _toggleDebtSelection(debt.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? debt.color.withOpacity(0.15)
                                : (widget.isDark
                                      ? Colors.white.withOpacity(0.03)
                                      : Colors.black.withOpacity(0.02)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? debt.color
                                  : (widget.isDark
                                        ? Colors.white12
                                        : Colors.black12),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: isSelected ? debt.color : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                debt.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isDisabled
                                      ? Colors.grey
                                      : (isSelected
                                            ? debt.color
                                            : (widget.isDark
                                                  ? Colors.white70
                                                  : Colors.black54)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${CurrencyUtils.getCurrencySymbol(debt.currency)}${debt.currentBalance.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: widget.isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: debt.color,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  if (_hasMixedCurrencies) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You have debts in multiple currencies. Only same-currency debts can be combined.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Mode & Strategy Row
                  Row(
                    children: [
                      _buildModeButton(
                        CalculatorMode.plan,
                        'Plan',
                        Icons.calendar_month_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildModeButton(
                        CalculatorMode.immediate,
                        'Lump Sum',
                        Icons.flash_on_rounded,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Payment Strategy (only for multi-debt plan mode)
                  if (_mode == CalculatorMode.plan &&
                      _selectedDebts.length > 1) ...[
                    Text(
                      'PAYMENT STRATEGY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: widget.isDark ? Colors.white38 : Colors.black38,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildStrategyChip(
                          PaymentStrategy.avalanche,
                          'Avalanche',
                          'Highest APR first',
                        ),
                        const SizedBox(width: 8),
                        _buildStrategyChip(
                          PaymentStrategy.snowball,
                          'Snowball',
                          'Smallest balance first',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Frequency & Times Per
                  if (_mode == CalculatorMode.plan) ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FREQUENCY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: widget.isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.isDark
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.black.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<CalculatorFrequency>(
                                    value: _frequency,
                                    isExpanded: true,
                                    onChanged: (v) {
                                      setState(() => _frequency = v!);
                                      _calculateResults();
                                    },
                                    items: CalculatorFrequency.values
                                        .map(
                                          (f) => DropdownMenuItem(
                                            value: f,
                                            child: Text(_getFrequencyLabel(f)),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '× PER',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: widget.isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _intervalController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                onChanged: (_) => _calculateResults(),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: widget.isDark
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.black.withOpacity(0.03),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Payment Amount
                  Text(
                    _mode == CalculatorMode.plan
                        ? 'PAYMENT AMOUNT'
                        : 'LUMP SUM AMOUNT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: widget.isDark ? Colors.white38 : Colors.black38,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _paymentController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFCDAF56),
                    ),
                    onChanged: (_) => _calculateResults(),
                    decoration: InputDecoration(
                      prefixText: CurrencyUtils.getCurrencySymbol(
                        _primaryCurrency,
                      ),
                      prefixStyle: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFCDAF56),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFCDAF56).withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(20),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Results
                  if (_totalOccurrences != null) ...[
                    if (_totalOccurrences == -1)
                      _buildAlert(
                        'Payment Too Low',
                        'Your payment doesn\'t cover the combined interest. Increase your payment to make progress.',
                        Icons.warning_amber_rounded,
                        Colors.red,
                      )
                    else if (_mode == CalculatorMode.immediate)
                      _buildImmediateResult()
                    else
                      _buildPlanResults(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyChip(
    PaymentStrategy strategy,
    String label,
    String desc,
  ) {
    final isActive = _strategy == strategy;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _strategy = strategy);
          _calculateResults();
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFCDAF56).withOpacity(0.1)
                : (widget.isDark
                      ? Colors.white.withOpacity(0.03)
                      : Colors.black.withOpacity(0.02)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? const Color(0xFFCDAF56)
                  : (widget.isDark ? Colors.white12 : Colors.black12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isActive
                      ? const Color(0xFFCDAF56)
                      : (widget.isDark ? Colors.white : Colors.black87),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 10,
                  color: widget.isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(CalculatorMode mode, String label, IconData icon) {
    final isActive = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _mode = mode);
          _calculateResults();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFCDAF56)
                : (widget.isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? const Color(0xFFCDAF56)
                  : (widget.isDark ? Colors.white12 : Colors.black12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive
                    ? Colors.white
                    : (widget.isDark ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isActive
                      ? Colors.white
                      : (widget.isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImmediateResult() {
    final symbol = CurrencyUtils.getCurrencySymbol(_primaryCurrency);
    final isFullyPaid = _remainingBalance <= 0.01;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isFullyPaid
                ? Colors.green.withOpacity(0.1)
                : (widget.isDark
                      ? Colors.white.withOpacity(0.03)
                      : Colors.black.withOpacity(0.02)),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isFullyPaid
                  ? Colors.green.withOpacity(0.3)
                  : (widget.isDark ? Colors.white10 : Colors.black12),
            ),
          ),
          child: Column(
            children: [
              Text(
                'Remaining Balance',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$symbol${_remainingBalance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: isFullyPaid
                      ? Colors.green
                      : (widget.isDark ? Colors.white : Colors.black87),
                ),
              ),
              if (isFullyPaid) ...[
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.celebration_rounded,
                      color: Colors.green,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'ALL SELECTED DEBTS CLEARED!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (_debtResults.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildDebtBreakdown(),
        ],
      ],
    );
  }

  Widget _buildPlanResults() {
    final symbol = CurrencyUtils.getCurrencySymbol(_primaryCurrency);
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.isDark
                  ? [
                      const Color(0xFFCDAF56).withOpacity(0.2),
                      const Color(0xFFCDAF56).withOpacity(0.05),
                    ]
                  : [const Color(0xFFCDAF56).withOpacity(0.1), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFCDAF56).withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                'Debt Freedom',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('MMMM yyyy').format(_payoffDate!),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: widget.isDark ? Colors.white : Colors.black87,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  '$_totalOccurrences ${_frequency.name} payments',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatCard(
              'Interest',
              '$symbol${_totalInterestPaid.toStringAsFixed(2)}',
              Icons.trending_up_rounded,
              Colors.orange,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              'Total Cost',
              '$symbol${_totalPaidTotal.toStringAsFixed(2)}',
              Icons.account_balance_rounded,
              const Color(0xFFCDAF56),
            ),
          ],
        ),
        if (_debtResults.length > 1) ...[
          const SizedBox(height: 16),
          _buildDebtBreakdown(),
        ],
      ],
    );
  }

  Widget _buildDebtBreakdown() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEBT BREAKDOWN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: widget.isDark ? Colors.white38 : Colors.black38,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ..._debtResults.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: r.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.debtName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  if (r.payoffOccurrence != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${r.payoffOccurrence}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    )
                  else
                    Text(
                      '${CurrencyUtils.getCurrencySymbol(_primaryCurrency)}${r.finalBalance.toStringAsFixed(0)} left',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDark
              ? Colors.white.withOpacity(0.03)
              : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color.withOpacity(0.7)),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: widget.isDark ? Colors.white38 : Colors.black45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlert(String title, String message, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getFrequencyLabel(CalculatorFrequency f) {
    switch (f) {
      case CalculatorFrequency.daily:
        return 'Daily';
      case CalculatorFrequency.weekly:
        return 'Weekly';
      case CalculatorFrequency.biWeekly:
        return 'Bi-Weekly';
      case CalculatorFrequency.monthly:
        return 'Monthly';
    }
  }
}

class _WorkingDebt {
  final String id;
  final String name;
  double balance;
  final double apr;
  final Color color;
  final double originalBalance;
  double interestAccrued = 0;
  double totalPaid = 0;
  int? payoffOccurrence;

  _WorkingDebt({
    required this.id,
    required this.name,
    required this.balance,
    required this.apr,
    required this.color,
    required this.originalBalance,
  });
}

class _DebtPayoffResult {
  final String debtName;
  final double originalBalance;
  final double finalBalance;
  final double interestPaid;
  final double totalPaid;
  final int? payoffOccurrence;
  final Color color;

  _DebtPayoffResult({
    required this.debtName,
    required this.originalBalance,
    required this.finalBalance,
    required this.interestPaid,
    required this.totalPaid,
    this.payoffOccurrence,
    required this.color,
  });
}
