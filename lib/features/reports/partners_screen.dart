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

class PartnersScreen extends StatefulWidget {
  const PartnersScreen({super.key});
  @override
  State<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends State<PartnersScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final data = await client.get('/api/admin/auth/partners');
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
                'Partners',
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
            if (_loading)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Hero skeleton
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
                                    AppShimmer(width: 110, height: 12),
                                    SizedBox(height: 6),
                                    AppShimmer(width: 170, height: 18),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
                                      AppShimmer(width: 50, height: 15),
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
                    // KPI Grid
                    for (int row = 0; row < 2; row++) ...[
                      Row(
                        children: [
                          Expanded(child: _partnerKpiSkeleton()),
                          const SizedBox(width: 10),
                          Expanded(child: _partnerKpiSkeleton()),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 6),
                    // Investor cards skeleton
                    for (int i = 0; i < 2; i++) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const AppShimmer(
                                  width: 44,
                                  height: 44,
                                  borderRadius: 14,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          AppShimmer(width: 100, height: 15),
                                          SizedBox(width: 6),
                                          AppShimmer(
                                            width: 50,
                                            height: 16,
                                            borderRadius: 6,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      const AppShimmer(width: 140, height: 11),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  for (int j = 0; j < 3; j++) ...[
                                    if (j > 0) const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        children: const [
                                          AppShimmer(width: 50, height: 14),
                                          SizedBox(height: 4),
                                          AppShimmer(width: 40, height: 9),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
            'Failed to load',
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
    final o = _data!['overview'] as Map<String, dynamic>;
    final investors = (_data!['investors'] as List?) ?? [];
    final profitShares = (_data!['investorProfitShares'] as List?) ?? [];
    final partners = (_data!['partners'] as List?) ?? [];
    final alerts = (_data!['alerts'] as List?) ?? [];
    final sot = _data!['sourceOfTruth'] as Map<String, dynamic>?;

    return [
      if (sot != null) ...[
        PartnerWalletsHero(sot: sot),
        const SizedBox(height: 14),
        if (sot['monthClosingChart'] != null) ...[
          MonthClosingBarChart(months: sot['monthClosingChart'] as List),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            Expanded(
              child: _kpi(
                'Audited profit (mo)',
                fmtEgp(sot['auditedNetProfitThisMonth'] ?? 0),
                LucideIcons.circleCheck,
                AppColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _kpi(
                'MC cumulative',
                fmtEgp(sot['monthClosingCumulativeNet'] ?? 0),
                LucideIcons.calendarCheck,
                const Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],

      _buildHero(o),
      const SizedBox(height: 14),

      Row(
        children: [
          Expanded(
            child: _kpi(
              'Capital',
              _fmt(o['totalCapital']),
              LucideIcons.landmark,
              const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _kpi(
              'Wallet total',
              fmtEgp(o['totalWalletBalance'] ?? sot?['totalWalletBalance'] ?? 0),
              LucideIcons.wallet,
              const Color(0xFF8B5CF6),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _kpi(
              'Pending payout',
              '${o['pendingWithdrawals'] ?? 0}',
              LucideIcons.clock,
              AppColors.warning,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _kpi(
              'Partners',
              '${o['activeInvestors']}/${o['investorCount']}',
              LucideIcons.users,
              const Color(0xFF0EA5E9),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),

      // ── Alerts ──
      if (alerts.isNotEmpty) ...[
        _section('ALERTS', LucideIcons.bell, AppColors.error),
        const SizedBox(height: 10),
        ...alerts.take(3).map((a) => _alertCard(a)),
        const SizedBox(height: 16),
      ],

      // ── Profit Distribution Pie ──
      if (profitShares.isNotEmpty) ...[
        _buildProfitPie(profitShares),
        const SizedBox(height: 16),
      ],

      // ── Investors Section ──
      if (investors.isNotEmpty) ...[
        _section(
          'INVESTORS (${investors.length})',
          LucideIcons.users,
          const Color(0xFF0EA5E9),
        ),
        const SizedBox(height: 12),
        ...investors.map((inv) => _buildInvestorCard(inv)),
        const SizedBox(height: 16),
      ],

      // ── Partners Section ──
      if (partners.isNotEmpty) ...[
        _section(
          'COMMISSION PARTNERS (${partners.length})',
          LucideIcons.briefcase,
          const Color(0xFF8B5CF6),
        ),
        const SizedBox(height: 12),
        ...partners.map((p) => _buildPartnerCard(p)),
      ],
    ];
  }

  // ── Hero Card ──
  Widget _buildHero(Map<String, dynamic> o) {
    final profit = (o['netProfit'] as num?)?.toDouble() ?? 0;
    return Container(
      padding: const EdgeInsets.all(24),
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
                  LucideIcons.users,
                  color: Color(0xFF12403C),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Business Overview',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                  Text(
                    '${_fmt(o['totalRevenue'])} EGP Revenue',
                    style: GoogleFonts.inter(
                      fontSize: 18,
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
          const SizedBox(height: 14),
          Row(
            children: [
              _heroM('Revenue', _fmt(o['totalRevenue'])),
              Container(
                width: 1,
                height: 36,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              _heroM('Expenses', _fmt(o['totalExpenses'])),
              Container(
                width: 1,
                height: 36,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              _heroM('Profit', _fmt(profit)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroM(String l, String v) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(l, style: GoogleFonts.inter(fontSize: 10, color: Colors.white54)),
      ],
    ),
  );

  // ── Profit Distribution Pie ──
  Widget _buildProfitPie(List<dynamic> shares) {
    final colors = [
      const Color(0xFFE63946),
      const Color(0xFF457B9D),
      const Color(0xFF8338EC),
      const Color(0xFFF77F00),
      const Color(0xFF06D6A0),
      const Color(0xFF118AB2),
      const Color(0xFFEF476F),
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
          _section(
            'PROFIT DISTRIBUTION',
            LucideIcons.pieChart,
            const Color(0xFF6366F1),
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                  sections: shares.asMap().entries.map((e) {
                    final share =
                        ((e.value['profitShare'] as num?)?.toDouble() ?? 0)
                            .abs();
                    return PieChartSectionData(
                      value: share == 0 ? 1 : share,
                      title: '',
                      radius: 40,
                      color: colors[e.key % colors.length],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...shares.asMap().entries.map((e) {
            final s = e.value;
            final share = (s['share'] as num?)?.toDouble() ?? 0;
            final profit = (s['profitShare'] as num?)?.toDouble() ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[e.key % colors.length],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s['name'] ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(share * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _fmt(profit),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
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

  // ── Investor Card ──
  Widget _buildInvestorCard(dynamic inv) {
    final share = (inv['currentShare'] as num?)?.toDouble() ?? 0;
    final deposits = (inv['totalDeposits'] as num?)?.toDouble() ?? 0;
    final withdrawals = (inv['totalWithdrawals'] as num?)?.toDouble() ?? 0;
    final net = (inv['netContributed'] as num?)?.toDouble() ?? 0;
    final isActive = inv['isActive'] == true;
    final recentTx = (inv['recentTransactions'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? AppColors.cardBorder
              : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryDark,
                      AppColors.primaryDark.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    (inv['name'] ?? 'U')[0].toUpperCase(),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            inv['name'] ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isActive ? AppColors.success : AppColors.error)
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isActive ? 'ACTIVE' : 'INACTIVE',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${(inv['type'] ?? 'PARTNER').toString()} · Share: ${(share * 100).toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Financial summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _finCol('Deposits', _fmt(deposits), AppColors.success),
                Container(width: 1, height: 36, color: AppColors.cardBorder),
                _finCol('Withdrawals', _fmt(withdrawals), AppColors.error),
                Container(width: 1, height: 36, color: AppColors.cardBorder),
                _finCol(
                  'Net',
                  _fmt(net),
                  net >= 0 ? AppColors.primaryDark : AppColors.error,
                ),
              ],
            ),
          ),

          // Recent transactions
          if (recentTx.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Recent Transactions',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            ...recentTx.take(3).map((tx) => _txRow(tx, isInvestor: true)),
          ],
        ],
      ),
    );
  }

  // ── Partner Card ──
  Widget _buildPartnerCard(dynamic p) {
    final rate = (p['commissionRate'] as num?)?.toDouble() ?? 0;
    final wallet = (p['walletBalance'] as num?)?.toDouble() ?? 0;
    final commissions = (p['totalCommissions'] as num?)?.toDouble() ?? 0;
    final payouts = (p['totalPayouts'] as num?)?.toDouble() ?? 0;
    final thisMonth = (p['thisMonthCommissions'] as num?)?.toDouble() ?? 0;
    final lastMonth = (p['lastMonthCommissions'] as num?)?.toDouble() ?? 0;
    final isActive = p['isActive'] == true;
    final recentTx = (p['recentTransactions'] as List?) ?? [];
    final growth = lastMonth > 0
        ? ((thisMonth - lastMonth) / lastMonth * 100)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? AppColors.cardBorder
              : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    (p['name'] ?? 'P')[0].toUpperCase(),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p['name'] ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${(rate * 100).toStringAsFixed(0)}%',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Code: ${p['code'] ?? '-'} · ${p['orderCount'] ?? 0} orders',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Wallet Balance
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wallet Balance',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      '${_fmt(wallet)} EGP',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
                if (growth != 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (growth >= 0 ? AppColors.success : AppColors.error)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          growth >= 0
                              ? LucideIcons.trendingUp
                              : LucideIcons.trendingDown,
                          size: 12,
                          color: growth >= 0
                              ? AppColors.success
                              : AppColors.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${growth.abs().toStringAsFixed(0)}%',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: growth >= 0
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Financial row
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _finCol(
                      'Commissions',
                      _fmt(commissions),
                      AppColors.success,
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: AppColors.cardBorder,
                    ),
                    _finCol('Payouts', _fmt(payouts), AppColors.error),
                    Container(
                      width: 1,
                      height: 36,
                      color: AppColors.cardBorder,
                    ),
                    _finCol(
                      'Pending',
                      _fmt(commissions - payouts),
                      const Color(0xFFF59E0B),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(height: 1, color: AppColors.cardBorder),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _miniStat('This Month', '${_fmt(thisMonth)} EGP'),
                    _miniStat('Last Month', '${_fmt(lastMonth)} EGP'),
                  ],
                ),
              ],
            ),
          ),

          // Recent transactions
          if (recentTx.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Recent Transactions',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            ...recentTx.take(3).map((tx) => _txRow(tx, isInvestor: false)),
          ],
        ],
      ),
    );
  }

  // ── Transaction Row ──
  Widget _txRow(dynamic tx, {required bool isInvestor}) {
    final type = (tx['type'] ?? '').toString().toUpperCase();
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
    final isCredit = type == 'DEPOSIT' || type == 'COMMISSION';
    final date = DateTime.tryParse(tx['date'] ?? '');
    final dateStr = date != null ? DateFormat('d MMM').format(date) : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isCredit ? AppColors.success : AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              type,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}${_fmt(amount)}',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isCredit ? AppColors.success : AppColors.error,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            dateStr,
            style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ── Alert Card ──
  Widget _alertCard(dynamic alert) {
    final severity = (alert['severity'] ?? '').toString();
    final color = severity == 'critical'
        ? AppColors.error
        : severity == 'warning'
        ? AppColors.warning
        : AppColors.info;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            severity == 'critical'
                ? LucideIcons.alertOctagon
                : LucideIcons.alertTriangle,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert['title'] ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  alert['message'] ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textMuted,
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

  // ── Helpers ──
  Widget _finCol(String l, String v, Color c) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: c,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l,
          style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted),
        ),
      ],
    ),
  );

  Widget _miniStat(String l, String v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        l,
        style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted),
      ),
      Text(
        v,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ],
  );

  Widget _kpi(String label, String value, IconData icon, Color color) {
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
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
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

  Widget _section(String title, IconData icon, Color color) {
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
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    final n = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }

  Widget _partnerKpiSkeleton() {
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
