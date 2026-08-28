import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:admin_app/core/widgets/app_shimmer.dart';
import 'package:admin_app/features/reports/insights_widgets.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});
  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final data = await client.get('/api/admin/auth/finance');
      if (mounted)
        setState(() {
          _data = data;
          _isLoading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primaryDark,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.background,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: 64,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              leading: IconButton(
                icon: const Icon(
                  LucideIcons.arrowLeft,
                  color: AppColors.primaryDark,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Finance',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    LucideIcons.refreshCw,
                    size: 20,
                    color: AppColors.primaryDark,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _load();
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
            if (_isLoading)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Profit Hero skeleton
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              AppShimmer(
                                width: 42,
                                height: 42,
                                borderRadius: 14,
                              ),
                              AppShimmer(
                                width: 80,
                                height: 26,
                                borderRadius: 10,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const AppShimmer(width: 100, height: 13),
                          const SizedBox(height: 6),
                          const AppShimmer(width: 180, height: 30),
                          const SizedBox(height: 16),
                          Container(height: 1, color: AppColors.cardBorder),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              for (int i = 0; i < 3; i++) ...[
                                if (i > 0) const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    children: const [
                                      AppShimmer(width: 50, height: 14),
                                      SizedBox(height: 4),
                                      AppShimmer(width: 40, height: 10),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // KPI Grid (3 rows)
                    for (int row = 0; row < 3; row++) ...[
                      Row(
                        children: [
                          Expanded(child: _financeKpiSkeleton()),
                          const SizedBox(width: 10),
                          Expanded(child: _financeKpiSkeleton()),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 6),
                    // Monthly comparison skeleton
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              AppShimmer(
                                width: 26,
                                height: 26,
                                borderRadius: 8,
                              ),
                              SizedBox(width: 10),
                              AppShimmer(width: 110, height: 12),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              for (int i = 0; i < 2; i++) ...[
                                if (i > 0) const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: const [
                                        AppShimmer(width: 70, height: 10),
                                        SizedBox(height: 8),
                                        AppShimmer(width: 90, height: 14),
                                        SizedBox(height: 4),
                                        AppShimmer(width: 60, height: 10),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          const AppShimmer(
                            width: double.infinity,
                            height: 40,
                            borderRadius: 12,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Chart skeleton
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              AppShimmer(
                                width: 26,
                                height: 26,
                                borderRadius: 8,
                              ),
                              SizedBox(width: 10),
                              AppShimmer(width: 120, height: 12),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 180,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                for (final h in [
                                  80.0,
                                  120.0,
                                  100.0,
                                  140.0,
                                  90.0,
                                  110.0,
                                ])
                                  AppShimmer(
                                    width: 14,
                                    height: h,
                                    borderRadius: 4,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Payment breakdown skeleton
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              AppShimmer(
                                width: 26,
                                height: 26,
                                borderRadius: 8,
                              ),
                              SizedBox(width: 10),
                              AppShimmer(width: 130, height: 12),
                            ],
                          ),
                          const SizedBox(height: 16),
                          for (int i = 0; i < 3; i++) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    AppShimmer(
                                      width: 10,
                                      height: 10,
                                      borderRadius: 3,
                                    ),
                                    const SizedBox(width: 8),
                                    AppShimmer(
                                      width: 50 + (i * 10).toDouble(),
                                      height: 12,
                                    ),
                                  ],
                                ),
                                const AppShimmer(width: 60, height: 12),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const AppShimmer(
                              width: double.infinity,
                              height: 5,
                              borderRadius: 3,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  ]),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(child: _buildError())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(_buildContent()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.wifiOff,
            size: 48,
            color: AppColors.error.withValues(alpha: 0.5),
          ),
          SizedBox(height: 12),
          Text(
            'Failed to load finance data',
            style: GoogleFonts.inter(
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContent() {
    final insights = _data!['insights'] as Map<String, dynamic>?;
    final o = _data!['overview'] as Map<String, dynamic>;
    final thisMonth = _data!['thisMonth'] as Map<String, dynamic>? ?? {};
    final lastMonth = _data!['lastMonth'] as Map<String, dynamic>? ?? {};
    final growth = _data!['growth'] as Map<String, dynamic>? ?? {};
    final pending = _data!['pendingExpenses'] as Map<String, dynamic>? ?? {};
    final categories = (_data!['expensesByCategory'] as List?) ?? [];
    final payments = (_data!['paymentBreakdown'] as List?) ?? [];
    final trend = (_data!['monthlyTrend'] as List?) ?? [];
    final expenses = (_data!['recentExpenses'] as List?) ?? [];

    return [
      if (insights != null) ...[
        FinancialTruthHero(
          treasury: Map<String, dynamic>.from(insights['treasury'] as Map? ?? {}),
          audited: Map<String, dynamic>.from(insights['auditedOrders'] as Map? ?? {}),
          cashFlow: Map<String, dynamic>.from(insights['cashFlow'] as Map? ?? {}),
        ),
        const SizedBox(height: 14),
        if ((insights['cashFlow']?['dailyTrend'] as List?)?.isNotEmpty == true) ...[
          CashFlowBarChart(dailyTrend: insights['cashFlow']['dailyTrend'] as List),
          const SizedBox(height: 14),
        ],
        if (insights['cashFlow']?['byReference'] != null) ...[
          CashReferenceTable(items: insights['cashFlow']['byReference'] as List),
          const SizedBox(height: 14),
        ],
        if (insights['expenses']?['byType'] != null) ...[
          ExpenseTypePieChart(byType: Map<String, dynamic>.from(insights['expenses']['byType'] as Map)),
          const SizedBox(height: 14),
        ],
        _buildMonthClosingChart(insights['monthClosing'] as Map<String, dynamic>?),
        const SizedBox(height: 14),
        _buildReconciliationCard(insights['reconciliation'] as Map<String, dynamic>?),
        const SizedBox(height: 14),
      ],

      _buildProfitHero(o),
      const SizedBox(height: 14),

      // ── Revenue / Expenses / Margin KPIs ──
      Row(
        children: [
          Expanded(
            child: _kpiCard(
              'Cash on hand',
              _fmt(o['cashOnHand'] ?? insights?['treasury']?['totalBalance'] ?? 0),
              LucideIcons.landmark,
              AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _kpiCard(
              'Audited profit',
              _fmt(o['auditedNetProfit'] ?? 0),
              LucideIcons.circleCheck,
              AppColors.success,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _kpiCard(
              'Expense cash out',
              _fmt(o['expenseCashOut'] ?? 0),
              LucideIcons.receipt,
              AppColors.error,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _kpiCard(
              'Inventory',
              _fmt(o['inventoryBookValue'] ?? 0),
              LucideIcons.package,
              const Color(0xFF7C3AED),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _kpiCard(
              'Avg Order',
              '${_fmt(o['averageOrderValue'])} EGP',
              LucideIcons.calculator,
              const Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _kpiCard(
              'Outstanding',
              '${_fmt(o['outstandingPayables'])} EGP',
              LucideIcons.building,
              const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _kpiCard(
              'Shipping Cost',
              '${_fmt(o['totalShipping'])} EGP',
              LucideIcons.truck,
              const Color(0xFF059669),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _kpiCard(
              'Discount Cost',
              '${_fmt(o['totalDiscounts'])} EGP',
              LucideIcons.tag,
              const Color(0xFFF97316),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),

      // ── Pending Alert ──
      if ((pending['count'] as num? ?? 0) > 0) ...[
        _buildPendingAlert(pending),
        const SizedBox(height: 16),
      ],

      // ── Monthly Comparison ──
      _buildMonthlyComparison(thisMonth, lastMonth, growth),
      const SizedBox(height: 16),

      // ── Monthly Revenue Chart ──
      if (trend.isNotEmpty) ...[
        _buildRevenueChart(trend),
        const SizedBox(height: 16),
      ],

      // ── Payment Breakdown ──
      if (payments.isNotEmpty) ...[
        _buildPaymentBreakdown(payments),
        const SizedBox(height: 16),
      ],

      // ── Expense Categories ──
      if (categories.isNotEmpty) ...[
        _buildExpenseCategories(categories),
        const SizedBox(height: 16),
      ],

      // ── Recent Expenses ──
      if (expenses.isNotEmpty) ...[
        _sectionHeader('RECENT EXPENSES', LucideIcons.receipt, AppColors.error),
        const SizedBox(height: 10),
        ...expenses.take(10).map((e) => _buildExpenseCard(e)),
      ],
    ];
  }

  // ── Hero Profit Card ──
  Widget _buildProfitHero(Map<String, dynamic> o) {
    final profit = (o['netProfit'] as num?)?.toDouble() ?? 0;
    final margin = (o['profitMargin'] as num?)?.toInt() ?? 0;
    final isAdvanced = o['isUsingAdvancedProfit'] == true;
    final isPositive = profit >= 0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive
              ? [const Color(0xFF12403C), const Color(0xFF1A5C56)]
              : [const Color(0xFF5C1A1A), const Color(0xFF7C2D2D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isPositive ? AppColors.primaryDark : AppColors.error)
                .withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isPositive
                      ? LucideIcons.trendingUp
                      : LucideIcons.trendingDown,
                  color: const Color(0xFF12403C),
                  size: 22,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$margin% margin',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'True Net Profit',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white60,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '${_fmt(profit)} EGP',
            style: GoogleFonts.playfairDisplay(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 14),
          if (isAdvanced) ...[
            Row(
              children: [
                _heroMini('Revenue', _fmt(o['totalRevenue'])),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                _heroMini('COGS', _fmt(o['cogs']), color: Colors.white70),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                _heroMini('Gross Profit', _fmt(o['grossProfit'])),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _heroMini(
                  'Expenses',
                  _fmt(o['totalExpenses']),
                  color: Colors.white70,
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                _heroMini(
                  'Salaries',
                  _fmt(o['totalSalaries']),
                  color: Colors.white70,
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                _heroMini('Orders', '${o['deliveredOrdersCount'] ?? 0}'),
              ],
            ),
          ] else ...[
            Row(
              children: [
                _heroMini('Revenue', _fmt(o['totalRevenue'])),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                _heroMini(
                  'Expenses',
                  _fmt(o['totalExpenses']),
                  color: Colors.white70,
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                _heroMini('Orders', '${o['deliveredOrdersCount'] ?? 0}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _heroMini(String label, String value, {Color color = Colors.white}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 9, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  // ── Pending Alert ──
  Widget _buildPendingAlert(Map<String, dynamic> pending) {
    final count = (pending['count'] as num?)?.toInt() ?? 0;
    final total = (pending['total'] as num?)?.toDouble() ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              LucideIcons.clock,
              color: AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count Pending Expenses',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
                Text(
                  '${_fmt(total)} EGP awaiting approval',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            LucideIcons.alertTriangle,
            size: 18,
            color: AppColors.warning.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }

  // ── Monthly Comparison ──
  Widget _buildMonthlyComparison(
    Map<String, dynamic> thisM,
    Map<String, dynamic> lastM,
    Map<String, dynamic> growth,
  ) {
    final revGrowth = (growth['revenueGrowth'] as num?)?.toDouble() ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'MONTHLY P&L',
            LucideIcons.calendar,
            const Color(0xFF6366F1),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _monthCol('This Month', thisM)),
              const SizedBox(width: 12),
              Expanded(child: _monthCol('Last Month', lastM)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (revGrowth >= 0 ? AppColors.success : AppColors.error)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  revGrowth >= 0
                      ? LucideIcons.trendingUp
                      : LucideIcons.trendingDown,
                  size: 16,
                  color: revGrowth >= 0 ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 8),
                Text(
                  '${revGrowth.abs().toStringAsFixed(1)}% revenue ${revGrowth >= 0 ? 'growth' : 'decline'}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: revGrowth >= 0 ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthCol(String label, Map<String, dynamic> data) {
    final rev = (data['revenue'] as num?)?.toDouble() ?? 0;
    final exp = (data['expenses'] as num?)?.toDouble() ?? 0;
    final profit = (data['profit'] as num?)?.toDouble() ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          _miniRow('Revenue', _fmt(rev), AppColors.success),
          const SizedBox(height: 4),
          _miniRow('Expenses', _fmt(exp), AppColors.error),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Container(height: 1, color: AppColors.cardBorder),
          ),
          _miniRow(
            'Profit',
            _fmt(profit),
            profit >= 0 ? AppColors.primaryDark : AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _miniRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  // ── Revenue Chart ──
  Widget _buildRevenueChart(List<dynamic> trend) {
    final maxY = trend.fold<double>(
      0,
      (m, d) => max(m, (d['revenue'] as num).toDouble()),
    );
    final spots = trend
        .asMap()
        .entries
        .map(
          (e) =>
              FlSpot(e.key.toDouble(), (e.value['revenue'] as num).toDouble()),
        )
        .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'MONTHLY REVENUE',
            LucideIcons.barChart3,
            AppColors.success,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: AppColors.cardBorder, strokeWidth: 0.5),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (v, _) => Text(
                        _fmtK(v),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= trend.length)
                          return const SizedBox.shrink();
                        final month = (trend[i]['month'] as String).substring(
                          5,
                        );
                        return Text(
                          month,
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            color: AppColors.textMuted,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                maxY: maxY * 1.2 + 100,
                barGroups: spots
                    .map(
                      (s) => BarChartGroupData(
                        x: s.x.toInt(),
                        barRods: [
                          BarChartRodData(
                            toY: s.y,
                            width: 14,
                            color: AppColors.success.withValues(alpha: 0.8),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Payment Breakdown ──
  Widget _buildPaymentBreakdown(List<dynamic> payments) {
    final total = payments.fold<double>(
      0,
      (s, p) => s + ((p['revenue'] as num?)?.toDouble() ?? 0),
    );
    final colors = [
      const Color(0xFF10B981),
      const Color(0xFF0EA5E9),
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B),
      AppColors.error,
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'PAYMENT METHODS',
            LucideIcons.creditCard,
            const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 16),
          ...payments.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            final rev = (p['revenue'] as num?)?.toDouble() ?? 0;
            final orders = (p['orders'] as num?)?.toInt() ?? 0;
            final pct = total > 0 ? (rev / total * 100) : 0;
            final color = colors[i % colors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            (p['method'] ?? 'Unknown').toString().toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${_fmt(rev)} EGP',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: pct / 100,
                            minHeight: 5,
                            backgroundColor: AppColors.cardBorder,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${pct.toStringAsFixed(0)}% · $orders orders',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: AppColors.textMuted,
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

  // ── Expense Categories ──
  Widget _buildExpenseCategories(List<dynamic> categories) {
    final totalExp = categories.fold<double>(
      0,
      (s, c) => s + ((c['amount'] as num?)?.toDouble() ?? 0),
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'EXPENSE CATEGORIES',
            LucideIcons.tag,
            AppColors.error,
          ),
          const SizedBox(height: 16),
          ...categories.map((c) {
            final amount = (c['amount'] as num?)?.toDouble() ?? 0;
            final count = (c['count'] as num?)?.toInt() ?? 0;
            final budget = c['budgetLimit'] as num?;
            final pct = totalExp > 0 ? (amount / totalExp * 100) : 0;
            final overBudget = budget != null && amount > budget.toDouble();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c['category'] ?? 'Unknown',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (overBudget) ...[
                        Icon(
                          LucideIcons.alertTriangle,
                          size: 12,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        '${_fmt(amount)} EGP',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: overBudget
                              ? AppColors.error
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: pct / 100,
                            minHeight: 5,
                            backgroundColor: AppColors.cardBorder,
                            color: overBudget
                                ? AppColors.error
                                : AppColors.warning,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${pct.toStringAsFixed(0)}% · $count items',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  if (budget != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Budget: ${_fmt(budget)} EGP',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: overBudget
                            ? AppColors.error
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Expense Card ──
  Widget _buildExpenseCard(dynamic expense) {
    final status = (expense['status'] ?? '').toString();
    final color = _expenseStatusColor(status);
    final date = DateTime.tryParse(expense['date'] ?? '');
    final dateStr = date != null ? DateFormat('d MMM yyyy').format(date) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(LucideIcons.receipt, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense['title'] ?? 'Expense',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      expense['category'] ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (expense['paidBy'] != null) ...[
                      Text(
                        ' · ',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        expense['paidBy'],
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_fmt(expense['amount'])} EGP',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status,
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dateStr,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helpers ──
  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Color _expenseStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return AppColors.success;
      case 'PENDING':
        return AppColors.warning;
      case 'REJECTED':
        return AppColors.error;
      case 'PAID':
        return const Color(0xFF0EA5E9);
      default:
        return AppColors.textMuted;
    }
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    final n = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }

  String _fmtK(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : v.toStringAsFixed(0);

  Widget _buildMonthClosingChart(Map<String, dynamic>? mc) {
    final months = (mc?['months'] as List?) ?? [];
    if (months.isEmpty) return const SizedBox.shrink();

    final spots = months.asMap().entries.map((e) {
      final m = e.value as Map<String, dynamic>;
      return FlSpot(e.key.toDouble(), (m['netProfit'] as num?)?.toDouble() ?? 0);
    }).toList();
    final maxAbs = spots.fold<double>(0, (m, s) => max(m, s.y.abs()));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('MONTH CLOSING NET PROFIT', LucideIcons.calendarCheck, const Color(0xFF6366F1)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxAbs * 1.2 + 50,
                minY: -maxAbs * 1.2 - 50,
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= months.length) return const SizedBox.shrink();
                        final m = months[i] as Map<String, dynamic>;
                        return Text('${m['month']}/${m['year']}', style: GoogleFonts.inter(fontSize: 8, color: AppColors.textMuted));
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: spots.map((s) => BarChartGroupData(
                  x: s.x.toInt(),
                  barRods: [
                    BarChartRodData(
                      toY: s.y,
                      width: 16,
                      color: s.y >= 0 ? AppColors.success : AppColors.error,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReconciliationCard(Map<String, dynamic>? r) {
    if (r == null) return const SizedBox.shrink();
    final gap = (r['unexplainedGap'] as num?)?.toDouble() ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.info, size: 18, color: AppColors.info),
              const SizedBox(width: 8),
              Text('Cash reconciliation', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          _reconRow('Audited revenue − expense cash', fmtEgp(r['impliedNet'] ?? 0)),
          _reconRow('Actual cash net (period)', fmtEgp(r['actualCashNet'] ?? 0)),
          _reconRow('Gap', fmtEgp(gap), highlight: gap.abs() > 100),
          if (r['note'] != null) ...[
            const SizedBox(height: 8),
            Text(r['note'].toString(), style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _reconRow(String l, String v, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
          Text(v, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: highlight ? AppColors.warning : AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _financeKpiSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppShimmer(width: 32, height: 32, borderRadius: 10),
          SizedBox(height: 12),
          AppShimmer(width: 80, height: 16),
          SizedBox(height: 4),
          AppShimmer(width: 60, height: 10),
        ],
      ),
    );
  }
}
