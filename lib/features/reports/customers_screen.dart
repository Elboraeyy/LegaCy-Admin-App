import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:admin_app/features/reports/customer_widgets.dart';
import 'package:admin_app/core/widgets/app_shimmer.dart';
import 'package:admin_app/features/reports/insights_widgets.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
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
      final data = await client.get('/api/admin/auth/customers');
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
                'Customers',
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
                    _custHeroSkeleton(),
                    const SizedBox(height: 14),
                    for (int row = 0; row < 3; row++) ...[
                      Row(
                        children: [
                          Expanded(child: _custKpiSkeleton()),
                          const SizedBox(width: 10),
                          Expanded(child: _custKpiSkeleton()),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 6),
                    for (int i = 0; i < 4; i++) ...[
                      _custCardSkeleton(),
                      const SizedBox(height: 16),
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

  Widget _buildError() => Center(
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

  List<Widget> _buildContent() {
    final o = _data!['overview'] as Map<String, dynamic>;
    final segments = _data!['segments'] as Map<String, dynamic>? ?? {};
    final topCust = (_data!['topCustomers'] as List?) ?? [];
    final loyalty = _data!['loyalty'] as Map<String, dynamic>? ?? {};
    final reviews = _data!['reviews'] as Map<String, dynamic>? ?? {};
    final risk = _data!['risk'] as Map<String, dynamic>? ?? {};
    final returns = _data!['returns'] as Map<String, dynamic>? ?? {};
    final coupons = _data!['coupons'] as Map<String, dynamic>? ?? {};
    final geo = (_data!['geography'] as List?) ?? [];
    final regTrend = (_data!['registrationTrend'] as List?) ?? [];
    final sot = _data!['sourceOfTruth'] as Map<String, dynamic>?;

    return [
      if (sot != null) ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.info, color: AppColors.warning, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Revenue in KPIs uses audited orders (Orders Audit), not all delivered.',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textPrimary, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: custKpi('Delivered rev.', fmtEgp(sot['deliveredRevenue'] ?? 0), LucideIcons.package, AppColors.info)),
            const SizedBox(width: 10),
            Expanded(child: custKpi('Audited rev.', fmtEgp(sot['auditedRevenue'] ?? 0), LucideIcons.circleCheck, AppColors.success)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: custKpi('Not audited', fmtEgp(sot['revenueNotInAudit'] ?? 0), LucideIcons.alertTriangle, AppColors.warning)),
            const SizedBox(width: 10),
            Expanded(child: custKpi('Pending audit', '${sot['pendingAuditCount'] ?? 0} orders', LucideIcons.clipboardList, AppColors.error)),
          ],
        ),
        const SizedBox(height: 14),
        if (sot['monthlyComparison'] != null)
          AuditedVsDeliveredChart(monthlyComparison: sot['monthlyComparison'] as List),
        const SizedBox(height: 16),
      ],

      _buildHero(o),
      const SizedBox(height: 14),

      // KPIs Row 1
      Row(
        children: [
          Expanded(
            child: custKpi(
              'Total Users',
              '${o['totalUsers'] ?? 0}',
              LucideIcons.users,
              const Color(0xFF6366F1),
              growth: (o['newCustomerGrowth'] as num?)?.toDouble(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: custKpi(
              'Active (30d)',
              '${o['activeUsers'] ?? 0}',
              LucideIcons.userCheck,
              AppColors.success,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      // KPIs Row 2
      Row(
        children: [
          Expanded(
            child: custKpi(
              'Avg CLV',
              '${fmtNum(o['avgCLV'])} EGP',
              LucideIcons.heart,
              AppColors.error,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: custKpi(
              'Avg Order',
              '${fmtNum(o['avgOrderValue'])} EGP',
              LucideIcons.shoppingBag,
              const Color(0xFF0EA5E9),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      // KPIs Row 3
      Row(
        children: [
          Expanded(
            child: custKpi(
              'Repeat Rate',
              '${o['repeatRate'] ?? 0}%',
              LucideIcons.repeat,
              AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: custKpi(
              'Abandoned',
              '${o['abandonedCarts'] ?? 0}',
              LucideIcons.shoppingCart,
              AppColors.warning,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),

      // Repeat vs One-time
      _buildRepeatCard(o),
      const SizedBox(height: 16),

      // Segments
      SegmentFunnel(segments: segments),
      const SizedBox(height: 16),

      // Registration Trend
      if (regTrend.isNotEmpty) ...[
        RegTrendChart(data: regTrend),
        const SizedBox(height: 16),
      ],

      // Top Customers
      if (topCust.isNotEmpty) ...[
        _buildTopCustomers(topCust),
        const SizedBox(height: 16),
      ],

      // Loyalty
      LoyaltyCard(loyalty: loyalty),
      const SizedBox(height: 16),

      // Reviews
      ReviewsCard(reviews: reviews),
      const SizedBox(height: 16),

      // Risk Profiles
      if ((risk['highRisk'] as List?)?.isNotEmpty == true ||
          (risk['distribution'] as List?)?.isNotEmpty == true) ...[
        _buildRiskCard(risk),
        const SizedBox(height: 16),
      ],

      // Returns
      _buildReturnsCard(returns, o),
      const SizedBox(height: 16),

      // Coupons
      _buildCouponsCard(coupons),
      const SizedBox(height: 16),

      // Geography
      GeoCard(geography: geo),
      const SizedBox(height: 16),
    ];
  }

  // ── Hero ──
  Widget _buildHero(Map<String, dynamic> o) {
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
                    'Customer Base',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                  Text(
                    '${o['totalUsers'] ?? 0} Users',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '+${o['newThisMonth'] ?? 0} this month',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 14),
          Row(
            children: [
              _heroM('Revenue', '${fmtNum(o['totalRevenue'])} EGP'),
              Container(
                width: 1,
                height: 36,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              _heroM('Orders', '${o['deliveredOrders'] ?? 0}'),
              Container(
                width: 1,
                height: 36,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              _heroM('Buyers', '${o['totalBuyers'] ?? 0}'),
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
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(l, style: GoogleFonts.inter(fontSize: 10, color: Colors.white54)),
      ],
    ),
  );

  // ── Repeat vs One-time ──
  Widget _buildRepeatCard(Map<String, dynamic> o) {
    final repeat = (o['repeatCustomers'] as num?)?.toInt() ?? 0;
    final oneTime = (o['oneTimeCustomers'] as num?)?.toInt() ?? 0;
    final total = repeat + oneTime;
    final repeatPct = total > 0 ? repeat / total : 0.0;

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
          custSection(
            'CUSTOMER RETENTION',
            LucideIcons.repeat,
            AppColors.primaryDark,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: repeatPct,
                            strokeWidth: 8,
                            backgroundColor: AppColors.cardBorder,
                            color: AppColors.success,
                          ),
                        ),
                        Text(
                          '${(repeatPct * 100).toStringAsFixed(0)}%',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Repeat Rate',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    _retentionRow('Repeat', repeat, AppColors.success),
                    const SizedBox(height: 8),
                    _retentionRow('One-time', oneTime, AppColors.warning),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _retentionRow(String l, int v, Color c) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 8),
      Text(l, style: GoogleFonts.inter(fontSize: 11)),
      const Spacer(),
      Text(
        '$v',
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: c,
        ),
      ),
    ],
  );

  // ── Top Customers ──
  Widget _buildTopCustomers(List<dynamic> customers) {
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
          custSection('TOP CUSTOMERS', LucideIcons.crown, AppColors.accent),
          const SizedBox(height: 14),
          ...customers.asMap().entries.take(7).map((e) {
            final i = e.key;
            final c = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: i < 3
                          ? AppColors.accent.withValues(alpha: 0.15)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: i < 3 ? AppColors.accent : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      c['name'] ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${c['orders']} orders',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${fmtNum(c['revenue'])} EGP',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
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

  // ── Risk Card ──
  Widget _buildRiskCard(Map<String, dynamic> risk) {
    final dist = (risk['distribution'] as List?) ?? [];
    final highRisk = (risk['highRisk'] as List?) ?? [];
    final colors = {
      'normal': AppColors.success,
      'low': const Color(0xFF0EA5E9),
      'medium': AppColors.warning,
      'high': AppColors.error,
      'critical': const Color(0xFF7C2D2D),
    };

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
          custSection(
            'RISK ANALYSIS',
            LucideIcons.shieldAlert,
            AppColors.error,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: dist.map((d) {
              final level = (d['level'] ?? '').toString();
              final count = (d['count'] as num?)?.toInt() ?? 0;
              final color = colors[level] ?? AppColors.textMuted;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      level.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$count',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          if (highRisk.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Flagged Users',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            ...highRisk
                .take(3)
                .map(
                  (u) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.alertTriangle,
                          size: 14,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                u['email'] ?? u['phone'] ?? '',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Score: ${u['score']} · ${u['returns']} returns · ${u['cancels']} cancels',
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
                  ),
                ),
          ],
        ],
      ),
    );
  }

  // ── Returns Card ──
  Widget _buildReturnsCard(
    Map<String, dynamic> returns,
    Map<String, dynamic> o,
  ) {
    final byStatus = (returns['byStatus'] as List?) ?? [];
    final total = (returns['total'] as num?)?.toInt() ?? 0;
    final rate = (returns['returnRate'] as num?)?.toInt() ?? 0;
    final disputes = (o['disputeCount'] as num?)?.toInt() ?? 0;

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
          custSection(
            'RETURNS & DISPUTES',
            LucideIcons.undo2,
            AppColors.warning,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _statBox(
                  'Returns',
                  '$total',
                  '$rate% rate',
                  AppColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statBox('Disputes', '$disputes', '', AppColors.error),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statBox(
                  'Cancelled',
                  '${o['cancelledOrders'] ?? 0}',
                  '',
                  AppColors.textMuted,
                ),
              ),
            ],
          ),
          if (byStatus.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: byStatus.map((s) {
                final status = (s['status'] ?? '').toString();
                return Chip(
                  label: Text(
                    '$status: ${s['count']}',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: AppColors.background,
                  side: BorderSide(color: AppColors.cardBorder),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statBox(String l, String v, String sub, Color c) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Text(
          v,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: c,
          ),
        ),
        Text(
          l,
          style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted),
        ),
        if (sub.isNotEmpty)
          Text(
            sub,
            style: GoogleFonts.inter(fontSize: 8, color: AppColors.textMuted),
          ),
      ],
    ),
  );

  // ── Coupons Card ──
  Widget _buildCouponsCard(Map<String, dynamic> coupons) {
    final topCoupons = (coupons['topCoupons'] as List?) ?? [];
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
          custSection(
            'COUPONS & PROMOTIONS',
            LucideIcons.tag,
            const Color(0xFF10B981),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _statBox(
                  'Total',
                  '${coupons['total'] ?? 0}',
                  '${coupons['active'] ?? 0} active',
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statBox(
                  'Usage',
                  '${coupons['totalUsage'] ?? 0}',
                  '${coupons['ordersWithCoupons'] ?? 0} orders',
                  const Color(0xFF0EA5E9),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statBox(
                  'Discounts',
                  fmtNum(coupons['discountGiven']),
                  'given',
                  AppColors.error,
                ),
              ),
            ],
          ),
          if (topCoupons.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Top Coupons',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            ...topCoupons
                .take(4)
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            c['code'] ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${c['type'] == 'percentage' ? '${(c['value'] as num).toInt()}%' : '${fmtNum(c['value'])} EGP'} off',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          '${c['used']}${c['limit'] != null ? '/${c['limit']}' : ''} used',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _custHeroSkeleton() {
    return Container(
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
              AppShimmer(width: 42, height: 42, borderRadius: 14),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppShimmer(width: 100, height: 12),
                    SizedBox(height: 6),
                    AppShimmer(width: 130, height: 24),
                  ],
                ),
              ),
              AppShimmer(width: 90, height: 22, borderRadius: 10),
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
    );
  }

  Widget _custKpiSkeleton() {
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

  Widget _custCardSkeleton() {
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
          Row(
            children: const [
              AppShimmer(width: 26, height: 26, borderRadius: 8),
              SizedBox(width: 10),
              AppShimmer(width: 140, height: 12),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Center(
                  child: AppShimmer(
                    width: 80,
                    height: 80,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    for (int i = 0; i < 2; i++) ...[
                      Row(
                        children: [
                          AppShimmer(width: 10, height: 10, borderRadius: 3),
                          const SizedBox(width: 8),
                          const AppShimmer(width: 50, height: 11),
                          const Spacer(),
                          const AppShimmer(width: 30, height: 13),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
