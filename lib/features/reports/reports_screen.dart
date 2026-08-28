import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:admin_app/features/reports/statistics_screen.dart';
import 'package:admin_app/features/reports/daily_report_screen.dart';
import 'package:admin_app/features/reports/finance_screen.dart';
import 'package:admin_app/features/reports/partners_screen.dart';
import 'package:admin_app/features/reports/customers_screen.dart';
import 'package:admin_app/core/widgets/app_shimmer.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _refreshKey = 0;

  Future<void> _refreshData() async {
    setState(() => _refreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.accent,
        child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            expandedHeight: 110,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 20),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'INSIGHTS',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reports & Analytics',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Hero Card — Statistics Dashboard
                _HeroReportCard(
                  icon: LucideIcons.barChart3,
                  title: 'Statistics Dashboard',
                  subtitle: 'Revenue trends, KPIs, charts & deep insights',
                  gradient: const [Color(0xFF12403C), Color(0xFF1A5C56)],
                  iconBg: AppColors.accent,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StatisticsScreen()),
                  ),
                ),
                const SizedBox(height: 16),

                // Secondary Cards Row
                Row(
                  children: [
                    Expanded(
                      child: _CompactReportCard(
                        icon: LucideIcons.calendarDays,
                        title: 'Daily\nReport',
                        color: const Color(0xFF0EA5E9),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DailyReportScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CompactReportCard(
                        icon: LucideIcons.wallet,
                        title: 'Finance\nOverview',
                        color: const Color(0xFF10B981),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FinanceScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Partners & Customers Row
                Row(
                  children: [
                    Expanded(
                      child: _CompactReportCard(
                        icon: LucideIcons.users,
                        title: 'Partners &\nInvestors',
                        color: const Color(0xFF8B5CF6),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PartnersScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CompactReportCard(
                        icon: LucideIcons.heart,
                        title: 'Customers &\nLoyalty',
                        color: const Color(0xFFE11D48),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CustomersScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Quick Stats Preview
                _QuickStatsPreview(key: ValueKey(_refreshKey)),
              ]),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

// ── Hero Card ──
class _HeroReportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final Color iconBg;
  final VoidCallback onTap;

  const _HeroReportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.iconBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: AppColors.primaryDark, size: 28),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white70,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.arrowRight,
                size: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compact Card ──
class _CompactReportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _CompactReportCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'View',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(LucideIcons.arrowRight, size: 12, color: color),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick Stats Preview (fetches from dashboard endpoint) ──
class _QuickStatsPreview extends StatefulWidget {
  const _QuickStatsPreview({super.key});

  @override
  State<_QuickStatsPreview> createState() => _QuickStatsPreviewState();
}

class _QuickStatsPreviewState extends State<_QuickStatsPreview> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final results = await Future.wait([
        client.get('/api/admin/auth/dashboard'),
        client.get('/api/admin/auth/insights?month=${DateTime.now().month}&year=${DateTime.now().year}'),
      ]);
      if (mounted)
        setState(() {
          _stats = {
            ...Map<String, dynamic>.from(results[0] as Map),
            'insights': results[1],
          };
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK OVERVIEW',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                for (int i = 0; i < 4; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 40,
                      color: AppColors.cardBorder,
                    ),
                  Expanded(
                    child: Column(
                      children: const [
                        AppShimmer(width: 40, height: 24),
                        SizedBox(height: 6),
                        AppShimmer(width: 50, height: 10),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          )
        else if (_stats != null)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                _miniStat(
                  'Cash\n(Treasury)',
                  _fmt((_stats!['insights']?['treasury']?['totalBalance'] as num?) ?? 0),
                  AppColors.primaryDark,
                ),
                _divider(),
                _miniStat(
                  'Audited\nProfit',
                  _fmt((_stats!['insights']?['auditedOrders']?['netProfit'] as num?) ?? 0),
                  AppColors.success,
                ),
                _divider(),
                _miniStat(
                  "Today's\nOrders",
                  '${_stats!['todayOrders'] ?? 0}',
                  AppColors.info,
                ),
                _divider(),
                _miniStat(
                  'Pending\nAudit',
                  '${_stats!['insights']?['auditedOrders']?['pendingAuditInPeriod'] ?? 0}',
                  AppColors.warning,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppColors.textMuted,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 40, color: AppColors.cardBorder);

  String _fmt(num v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}
