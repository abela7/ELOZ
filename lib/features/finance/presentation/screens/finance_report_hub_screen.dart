import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../data/services/finance_settings_service.dart';
import '../providers/finance_providers.dart';
import '../providers/finance_report_providers.dart';
import '../../utils/currency_utils.dart';
import 'expense_report_screen.dart';
import 'income_report_screen.dart';
import 'bills_report_screen.dart';
import 'lending_report_screen.dart';
import 'daily_finance_report_page.dart';
import 'weekly_finance_report_page.dart';
import 'monthly_finance_report_page.dart';
import 'yearly_finance_report_page.dart';

/// Hub landing page for the comprehensive finance report.
/// Presents 4 period cards (Daily, Weekly, Monthly, Yearly) and links to
/// deep-dive reports (Expense, Income, Bills, Lending).
class FinanceReportHubScreen extends ConsumerWidget {
  const FinanceReportHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyAsync = ref.watch(defaultCurrencyProvider);
    final currency =
        currencyAsync.value ?? FinanceSettingsService.fallbackCurrency;
    final summariesAsync = ref.watch(financeReportHubSummariesProvider(currency));
    final sym = CurrencyUtils.getCurrencySymbol(currency);

    final body = CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: Material(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                },
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: Color(0xFFCDAF56),
                  ),
                ),
              ),
            ),
          ),
          title: Text(
            'Finance Report',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
            ),
          ),
          centerTitle: false,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Text(
                'OVERVIEW BY PERIOD',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFCDAF56),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              summariesAsync.when(
                data: (summaries) => Column(
                  children: [
                    _PeriodCard(
                      icon: Icons.today_rounded,
                      label: 'Daily',
                      net: (summaries['daily']?['net'] as num?)?.toDouble() ?? 0,
                      sublabel: summaries['daily']?['label'] as String? ?? '',
                      currencySymbol: sym,
                      isDark: isDark,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DailyFinanceReportPage(
                            initialDate: DateTime.now(),
                            currency: currency,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PeriodCard(
                      icon: Icons.date_range_rounded,
                      label: 'Weekly',
                      net: (summaries['weekly']?['net'] as num?)?.toDouble() ?? 0,
                      sublabel: summaries['weekly']?['label'] as String? ?? '',
                      currencySymbol: sym,
                      isDark: isDark,
                      onTap: () {
                        final now = DateTime.now();
                        final weekday = now.weekday;
                        final weekStart = DateTime(
                          now.year,
                          now.month,
                          now.day - (weekday - 1),
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WeeklyFinanceReportPage(
                              initialWeekStart: weekStart,
                              currency: currency,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _PeriodCard(
                      icon: Icons.calendar_month_rounded,
                      label: 'Monthly',
                      net: (summaries['monthly']?['net'] as num?)?.toDouble() ?? 0,
                      sublabel: summaries['monthly']?['label'] as String? ?? '',
                      currencySymbol: sym,
                      isDark: isDark,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MonthlyFinanceReportPage(
                            initialMonth: DateTime(DateTime.now().year, DateTime.now().month, 1),
                            currency: currency,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PeriodCard(
                      icon: Icons.calendar_view_month_rounded,
                      label: 'Yearly',
                      net: (summaries['yearly']?['net'] as num?)?.toDouble() ?? 0,
                      sublabel: summaries['yearly']?['label'] as String? ?? '',
                      currencySymbol: sym,
                      isDark: isDark,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => YearlyFinanceReportPage(
                            initialYear: DateTime.now().year,
                            currency: currency,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFCDAF56)),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 28),
              Text(
                'DEEP DIVE REPORTS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFCDAF56),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              _DeepDiveTile(
                icon: Icons.receipt_long_rounded,
                label: 'Expense Report',
                isDark: isDark,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ExpenseReportScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _DeepDiveTile(
                icon: Icons.trending_up_rounded,
                label: 'Income Report',
                isDark: isDark,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const IncomeReportScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _DeepDiveTile(
                icon: Icons.account_balance_rounded,
                label: 'Bills & Subscriptions Report',
                isDark: isDark,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BillsReportScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _DeepDiveTile(
                icon: Icons.handshake_rounded,
                label: 'Lending Report',
                isDark: isDark,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LendingReportScreen(),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0F14) : const Color(0xFFF8F9FC),
      body: isDark ? DarkGradient.wrap(child: body) : body,
    );
  }
}

class _PeriodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final double net;
  final String sublabel;
  final String currencySymbol;
  final bool isDark;
  final VoidCallback onTap;

  const _PeriodCard({
    required this.icon,
    required this.label,
    required this.net,
    required this.sublabel,
    required this.currencySymbol,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final netStr = net >= 0
        ? '+$currencySymbol${net.toStringAsFixed(2)}'
        : '-$currencySymbol${(-net).toStringAsFixed(2)}';
    final color = net >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFFF5252);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFCDAF56).withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFCDAF56).withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 24, color: const Color(0xFFCDAF56)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Net: $netStr',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 24,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeepDiveTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _DeepDiveTile({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFFCDAF56)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
