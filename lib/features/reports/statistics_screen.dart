import 'package:admin_app/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:admin_app/features/reports/stats_widgets.dart';
import 'package:admin_app/features/reports/insights_widgets.dart';
import 'package:admin_app/core/widgets/app_shimmer.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  DateTimeRange? _selectedRange;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      String query = '';
      if (_selectedRange != null) {
        final startStr =
            '${_selectedRange!.start.year}-${_selectedRange!.start.month.toString().padLeft(2, '0')}-${_selectedRange!.start.day.toString().padLeft(2, '0')}';
        final endStr =
            '${_selectedRange!.end.year}-${_selectedRange!.end.month.toString().padLeft(2, '0')}-${_selectedRange!.end.day.toString().padLeft(2, '0')}';
        query = '?startDate=$startStr&endDate=$endStr';
      }
      final data = await client.get('/api/admin/auth/statistics$query');
      if (mounted)
        setState(() {
          _data = data;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  PreferredSizeWidget? get _statisticsTabBar => (_loading || _error != null)
      ? null
      : TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.accent,
          labelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(text: 'Finance'),
            Tab(text: 'Sales'),
            Tab(text: 'Operations'),
          ],
        );

  SliverAppBar _statisticsSliverAppBar({PreferredSizeWidget? bottom}) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 64,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft, color: AppColors.primaryDark),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Statistics',
        style: GoogleFonts.playfairDisplay(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
        ),
      ),
      actions: [
        if (_selectedRange != null)
          IconButton(
            icon: const Icon(LucideIcons.xCircle, size: 20, color: AppColors.error),
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedRange = null);
              _load();
            },
          ),
        IconButton(
          icon: Icon(
            LucideIcons.calendar,
            size: 20,
            color: _selectedRange != null ? AppColors.accent : AppColors.primaryDark,
          ),
          onPressed: _pickDate,
        ),
        IconButton(
          icon: const Icon(LucideIcons.refreshCw, size: 20, color: AppColors.primaryDark),
          onPressed: () {
            HapticFeedback.lightImpact();
            _load();
          },
        ),
        const SizedBox(width: 8),
      ],
      bottom: bottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _error == null && _data != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: RefreshIndicator(
          color: AppColors.primaryDark,
          onRefresh: _load,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: _statisticsSliverAppBar(bottom: _statisticsTabBar),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _statisticsTabBody(_buildFinanceTab()),
                _statisticsTabBody(_buildSalesTab()),
                _statisticsTabBody(_buildOpsTab()),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primaryDark,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _statisticsSliverAppBar(),
            if (_loading)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Hero skeleton
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              AppShimmer(
                                width: 42,
                                height: 42,
                                borderRadius: 14,
                              ),
                              SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppShimmer(width: 90, height: 12),
                                    SizedBox(height: 6),
                                    AppShimmer(width: 160, height: 24),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(height: 1, color: AppColors.cardBorder),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              for (int i = 0; i < 3; i++) ...[
                                if (i > 0) const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    children: const [
                                      AppShimmer(width: 50, height: 18),
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
                    const SizedBox(height: 16),
                    // KPI Grid (3 rows × 2)
                    for (int row = 0; row < 5; row++) ...[
                      Row(
                        children: [
                          Expanded(child: _kpiSkeleton()),
                          const SizedBox(width: 10),
                          Expanded(child: _kpiSkeleton()),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 10),
                    // Chart skeleton
                    _chartSkeleton(),
                    const SizedBox(height: 16),
                    _chartSkeleton(),
                    const SizedBox(height: 16),
                    // Cards
                    for (int i = 0; i < 3; i++) ...[
                      _cardSkeleton(),
                      const SizedBox(height: 16),
                    ],
                  ]),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(child: _buildError()),
          ],
        ),
      ),
    );
  }

  Widget _statisticsTabBody(List<Widget> children) {
    return Builder(
      builder: (context) {
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate(children),
              ),
            ),
          ],
        );
      },
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
          const SizedBox(height: 12),
          Text(
            'Failed to load statistics',
            style: GoogleFonts.inter(
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _error ?? '',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
            textAlign: TextAlign.center,
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

  List<Widget> _buildFinanceTab() {
    final sot = _data!['sourceOfTruth'] as Map<String, dynamic>?;
    if (sot == null) {
      return [
        Text(
          'Finance insights unavailable. Pull to refresh.',
          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
        ),
      ];
    }
    return [
      FinancialTruthHero(
        treasury: Map<String, dynamic>.from(sot['treasury'] as Map? ?? {}),
        audited: Map<String, dynamic>.from(sot['auditedOrders'] as Map? ?? {}),
        cashFlow: Map<String, dynamic>.from(sot['cashFlow'] as Map? ?? {}),
      ),
      const SizedBox(height: 16),
      if ((sot['cashFlow']?['dailyTrend'] as List?)?.isNotEmpty == true) ...[
        CashFlowBarChart(dailyTrend: sot['cashFlow']['dailyTrend'] as List),
        const SizedBox(height: 16),
      ],
      if (sot['cashFlow']?['byReference'] != null) ...[
        CashReferenceTable(items: sot['cashFlow']['byReference'] as List),
        const SizedBox(height: 16),
      ],
      if (sot['expenses']?['byType'] != null) ...[
        ExpenseTypePieChart(
          byType: Map<String, dynamic>.from(sot['expenses']['byType'] as Map),
        ),
        const SizedBox(height: 16),
      ],
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildOpsTab() {
    final sot = _data!['sourceOfTruth'] as Map<String, dynamic>?;
    final inv = sot?['inventory'] as Map<String, dynamic>?;
    final proc = sot?['procurement'] as Map<String, dynamic>?;
    final suppliers = (proc?['topSuppliersByBalance'] as List?) ?? [];

    return [
      Text(
        'INVENTORY & PROCUREMENT',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 1.5,
        ),
      ),
      const SizedBox(height: 12),
      OpsKpiRow(items: [
        (
          label: 'Inventory value',
          value: fmtEgp((inv?['bookValue'] as num?) ?? 0),
          icon: LucideIcons.package,
          color: const Color(0xFF7C3AED),
        ),
        (
          label: 'Low / OOS',
          value: '${inv?['lowStock'] ?? 0} / ${inv?['outOfStock'] ?? 0}',
          icon: LucideIcons.alertTriangle,
          color: AppColors.warning,
        ),
      ]),
      const SizedBox(height: 10),
      OpsKpiRow(items: [
        (
          label: 'Posted invoices',
          value: fmtEgp((proc?['postedInvoicesTotal'] as num?) ?? 0),
          icon: LucideIcons.fileText,
          color: const Color(0xFF0EA5E9),
        ),
        (
          label: 'Payables open',
          value: fmtEgp((proc?['outstandingPayables'] as num?) ?? 0),
          icon: LucideIcons.receipt,
          color: AppColors.warning,
        ),
      ]),
      const SizedBox(height: 16),
      if (suppliers.isNotEmpty)
        RankedListCard(
          title: 'TOP SUPPLIER BALANCES',
          icon: LucideIcons.truck,
          color: const Color(0xFF059669),
          items: suppliers,
          getName: (i) => i['name'] ?? '',
          getValue: (i) => fmtEgp((i['balance'] as num?) ?? 0),
        ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildSalesTab() {
    final o = _data!['overview'] as Map<String, dynamic>;
    final g = _data!['growth'] as Map<String, dynamic>;
    final status = _data!['statusDistribution'] as Map<String, dynamic>;
    final trend = (_data!['revenueTrend'] as List?) ?? [];
    final topProducts = (_data!['topProducts'] as List?) ?? [];
    final topCustomers = (_data!['topCustomers'] as List?) ?? [];
    final topCities = (_data!['topCities'] as List?) ?? [];
    final sources = (_data!['orderSources'] as List?) ?? [];
    final payments = (_data!['paymentMethods'] as List?) ?? [];
    final hourly = (_data!['hourlyDistribution'] as List?) ?? [];
    final weekly = _data!['weeklyComparison'] as Map<String, dynamic>? ?? {};

    return [
      // ── Hero Summary ──
      _buildHeroSummary(o, g),
      const SizedBox(height: 16),

      // ── KPI Grid ──
      Row(
        children: [
          Expanded(
            child: KpiCard(
              label: "Today's Orders",
              value: '${o['todayOrders']}',
              icon: LucideIcons.shoppingBag,
              color: AppColors.info,
              growth: (g['ordersGrowth'] as num?)?.toDouble(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: KpiCard(
              label: "Today's Revenue",
              value: '${_fmtNum(o['todayRevenue'])} EGP',
              icon: LucideIcons.trendingUp,
              color: AppColors.success,
              growth: (g['revenueGrowth'] as num?)?.toDouble(),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: KpiCard(
              label: 'Avg Order Value',
              value: '${_fmtNum(o['averageOrderValue'])} EGP',
              icon: LucideIcons.calculator,
              color: const Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: KpiCard(
              label: 'Total Customers',
              value: '${o['totalCustomers']}',
              icon: LucideIcons.users,
              color: const Color(0xFF0EA5E9),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: KpiCard(
              label: 'Pending Orders',
              value: '${status['pending'] ?? 0}',
              icon: LucideIcons.clock,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: KpiCard(
              label: 'Low Stock',
              value: '${o['lowStockCount']}',
              icon: LucideIcons.alertTriangle,
              color: AppColors.error,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),

      Row(
        children: [
          Expanded(
            child: KpiCard(
              label: 'Cancel Rate',
              value: '${o['cancellationRate'] ?? 0}%',
              icon: LucideIcons.xCircle,
              color: const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: KpiCard(
              label: 'Avg Delivery',
              value: '${o['avgFulfillmentDays'] ?? 0} d',
              icon: LucideIcons.truck,
              color: const Color(0xFF059669),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),

      // ── Revenue Chart ──
      RevenueChart(data: trend),
      const SizedBox(height: 16),

      // ── Orders Chart ──
      OrdersBarChart(data: trend),
      const SizedBox(height: 16),

      // ── Status Pie ──
      StatusPieChart(data: status),
      const SizedBox(height: 16),

      // ── Monthly Comparison ──
      _buildMonthlyComparison(o, g),
      const SizedBox(height: 16),

      // ── NEW: Weekly Comparison ──
      _buildWeeklyComparison(weekly, g),
      const SizedBox(height: 16),

      // ── Top Products ──
      RankedListCard(
        title: 'TOP PRODUCTS',
        icon: LucideIcons.package2,
        color: AppColors.accent,
        items: topProducts,
        getName: (i) => i['name'] ?? '',
        getValue: (i) => '×${i['quantity'] ?? 0}',
      ),
      const SizedBox(height: 16),

      // ── Top Customers ──
      RankedListCard(
        title: 'TOP CUSTOMERS',
        icon: LucideIcons.users,
        color: const Color(0xFF0EA5E9),
        items: topCustomers,
        getName: (i) => i['name'] ?? 'Guest',
        getValue: (i) => '${i['orders']} orders',
      ),
      const SizedBox(height: 16),

      // ── Top Cities ──
      BreakdownCard(
        title: 'TOP CITIES',
        icon: LucideIcons.mapPin,
        color: const Color(0xFF7C3AED),
        items: topCities,
        getLabel: (i) => i['city'] ?? 'Unknown',
        getCount: (i) => (i['orders'] as num?)?.toInt() ?? 0,
      ),
      const SizedBox(height: 16),

      // ── Order Sources ──
      BreakdownCard(
        title: 'ORDER SOURCES',
        icon: LucideIcons.globe,
        color: const Color(0xFF10B981),
        items: sources,
        getLabel: (i) => (i['source'] ?? 'unknown').toString().toUpperCase(),
        getCount: (i) => (i['count'] as num?)?.toInt() ?? 0,
      ),
      const SizedBox(height: 16),

      // ── Payment Methods ──
      BreakdownCard(
        title: 'PAYMENT METHODS',
        icon: LucideIcons.creditCard,
        color: const Color(0xFFF59E0B),
        items: payments,
        getLabel: (i) => (i['method'] ?? 'unknown').toString().toUpperCase(),
        getCount: (i) => (i['count'] as num?)?.toInt() ?? 0,
      ),
      const SizedBox(height: 16),

      // ── Peak Hours ──
      if (hourly.isNotEmpty) _buildPeakHours(hourly),
      const SizedBox(height: 16),

      _buildFinancialInsights(o),
      const SizedBox(height: 16),

      // ── Repeat Customers ──
      _buildRepeatCustomers(o),
      const SizedBox(height: 40),
    ];
  }

  Widget _buildHeroSummary(Map<String, dynamic> o, Map<String, dynamic> g) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF12403C), Color(0xFF1A5C56)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.3),
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
                child: const Icon(
                  LucideIcons.barChart3,
                  color: Color(0xFF12403C),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Revenue',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white60,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${_fmtNum(o['totalRevenue'])} EGP',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Row(
            children: [
              _heroMini('Total Orders', '${o['totalOrders']}'),
              Container(
                width: 1,
                height: 36,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              _heroMini('Products', '${o['totalProducts']}'),
              Container(
                width: 1,
                height: 36,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              _heroMini('This Month', _fmtNum(o['thisMonth']?['revenue'] ?? 0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMini(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyComparison(
    Map<String, dynamic> o,
    Map<String, dynamic> g,
  ) {
    final thisM = o['thisMonth'] as Map<String, dynamic>? ?? {};
    final lastM = o['lastMonth'] as Map<String, dynamic>? ?? {};
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
          SectionHeader(
            title: 'MONTHLY COMPARISON',
            icon: LucideIcons.calendar,
            color: const Color(0xFF6366F1),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _monthCol(
                  'This Month',
                  '${_fmtNum(thisM['revenue'] ?? 0)} EGP',
                  '${thisM['orders'] ?? 0} orders',
                  AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _monthCol(
                  'Last Month',
                  '${_fmtNum(lastM['revenue'] ?? 0)} EGP',
                  '${lastM['orders'] ?? 0} orders',
                  AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ((g['monthlyRevenueGrowth'] as num?) ?? 0) >= 0
                  ? AppColors.success.withValues(alpha: 0.08)
                  : AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  ((g['monthlyRevenueGrowth'] as num?) ?? 0) >= 0
                      ? LucideIcons.trendingUp
                      : LucideIcons.trendingDown,
                  size: 16,
                  color: ((g['monthlyRevenueGrowth'] as num?) ?? 0) >= 0
                      ? AppColors.success
                      : AppColors.error,
                ),
                const SizedBox(width: 8),
                Text(
                  '${((g['monthlyRevenueGrowth'] as num?) ?? 0).toStringAsFixed(1)}% revenue growth',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ((g['monthlyRevenueGrowth'] as num?) ?? 0) >= 0
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthCol(String label, String rev, String orders, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          rev,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          orders,
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildPeakHours(List<dynamic> hourly) {
    final sorted = List<dynamic>.from(hourly)
      ..sort((a, b) => (b['orders'] as num).compareTo(a['orders'] as num));
    final top3 = sorted.take(3).toList();
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
          SectionHeader(
            title: 'PEAK HOURS',
            icon: LucideIcons.clock,
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 14),
          ...top3.map((h) {
            final hour = (h['hour'] as num).toInt();
            final label = hour == 0
                ? '12 AM'
                : hour < 12
                ? '$hour AM'
                : hour == 12
                ? '12 PM'
                : '${hour - 12} PM';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${h['orders']} orders',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRepeatCustomers(Map<String, dynamic> o) {
    final rate = (o['repeatCustomerRate'] as num?)?.toInt() ?? 0;
    final count = (o['repeatCustomerCount'] as num?)?.toInt() ?? 0;
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
          SectionHeader(
            title: 'CUSTOMER LOYALTY',
            icon: LucideIcons.heart,
            color: AppColors.error,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$rate%',
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Text(
                      'Repeat Customer Rate',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '$count',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Text(
                      'Repeat\nBuyers',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialInsights(Map<String, dynamic> o) {
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
          SectionHeader(
            title: 'FINANCIAL INSIGHTS',
            icon: LucideIcons.wallet,
            color: const Color(0xFF0EA5E9),
          ),
          const SizedBox(height: 16),
          _insightRow(
            LucideIcons.truck,
            'Shipping Collected',
            '${_fmtNum(o['totalShipping'])} EGP',
            '${o['shippingPct'] ?? 0}% of revenue',
            const Color(0xFF059669),
          ),
          const SizedBox(height: 12),
          _insightRow(
            LucideIcons.tag,
            'Discounts Given',
            '${_fmtNum(o['totalDiscounts'])} EGP',
            '${o['discountPct'] ?? 0}% of revenue',
            const Color(0xFFF97316),
          ),
          const SizedBox(height: 12),
          _insightRow(
            LucideIcons.xCircle,
            'Cancellation Rate',
            '${o['cancellationRate'] ?? 0}%',
            '${status['cancelled'] ?? 0} cancelled orders',
            const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }

  Widget _insightRow(
    IconData icon,
    String label,
    String value,
    String sub,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> get status =>
      _data?['statusDistribution'] as Map<String, dynamic>? ?? {};

  Widget _buildWeeklyComparison(
    Map<String, dynamic> w,
    Map<String, dynamic> g,
  ) {
    final thisW = w['thisWeek'] as Map<String, dynamic>? ?? {};
    final lastW = w['lastWeek'] as Map<String, dynamic>? ?? {};
    final growth = (g['weeklyRevenueGrowth'] as num?)?.toDouble() ?? 0;
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
          SectionHeader(
            title: 'WEEKLY COMPARISON',
            icon: LucideIcons.calendarDays,
            color: const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _monthCol(
                  'This Week',
                  '${_fmtNum(thisW['revenue'] ?? 0)} EGP',
                  '${thisW['orders'] ?? 0} orders',
                  const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _monthCol(
                  'Last Week',
                  '${_fmtNum(lastW['revenue'] ?? 0)} EGP',
                  '${lastW['orders'] ?? 0} orders',
                  AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: growth >= 0
                  ? AppColors.success.withValues(alpha: 0.08)
                  : AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  growth >= 0
                      ? LucideIcons.trendingUp
                      : LucideIcons.trendingDown,
                  size: 16,
                  color: growth >= 0 ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 8),
                Text(
                  '${growth.toStringAsFixed(1)}% weekly revenue growth',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: growth >= 0 ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtNum(dynamic v) {
    if (v == null) return '0';
    final n = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }

  Future<void> _pickDate() async {
    HapticFeedback.lightImpact();
    DateTime? tempStart = _selectedRange?.start;
    DateTime? tempEnd = _selectedRange?.end;

    final picked = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter by Date Range',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a start and end date to filter the dashboard.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateSelector(
                          label: 'Start Date',
                          date: tempStart,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: tempStart ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              builder: (context, child) => Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: AppColors.primaryDark,
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setDialogState(() => tempStart = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDateSelector(
                          label: 'End Date',
                          date: tempEnd,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  tempEnd ?? tempStart ?? DateTime.now(),
                              firstDate: tempStart ?? DateTime(2020),
                              lastDate: DateTime.now(),
                              builder: (context, child) => Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: AppColors.primaryDark,
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setDialogState(() => tempEnd = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (tempStart != null &&
                              tempEnd != null &&
                              tempEnd!.isBefore(tempStart!)) {
                            ScaffoldMessenger.of(context).showAppToast(
                              AppToast.snackBar(
                                content: Text(
                                  'End date must be after start date',
                                  style: TextStyle(color: Colors.white),
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }
                          Navigator.pop(context, true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Apply',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (picked == true && tempStart != null && tempEnd != null) {
      setState(() {
        _selectedRange = DateTimeRange(start: tempStart!, end: tempEnd!);
      });
      _load();
    }
  }

  Widget _buildDateSelector({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.calendar,
                  size: 16,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    date != null ? DateFormat('d MMM').format(date) : 'Select',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: date != null
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _kpiSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          AppShimmer(width: 32, height: 32, borderRadius: 10),
          SizedBox(height: 12),
          AppShimmer(width: 80, height: 16),
          SizedBox(height: 4),
          AppShimmer(width: 60, height: 10),
        ],
      ),
    );
  }

  Widget _chartSkeleton() {
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
          const AppShimmer(width: 140, height: 12),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final h in [60.0, 100.0, 80.0, 120.0, 90.0, 110.0])
                  AppShimmer(width: 20, height: h, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const AppShimmer(width: 40, height: 40, borderRadius: 12),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                AppShimmer(width: 120, height: 14),
                SizedBox(height: 4),
                AppShimmer(width: 80, height: 10),
              ],
            ),
          ),
          const AppShimmer(width: 60, height: 14),
        ],
      ),
    );
  }
}
