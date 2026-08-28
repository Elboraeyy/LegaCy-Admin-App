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
import 'package:admin_app/core/widgets/app_shimmer.dart';
import 'package:admin_app/features/reports/insights_widgets.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});
  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;
  DateTimeRange _selectedRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );

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
      final startStr =
          '${_selectedRange.start.year}-${_selectedRange.start.month.toString().padLeft(2, '0')}-${_selectedRange.start.day.toString().padLeft(2, '0')}';
      final endStr =
          '${_selectedRange.end.year}-${_selectedRange.end.month.toString().padLeft(2, '0')}-${_selectedRange.end.day.toString().padLeft(2, '0')}';
      final data = await client.get(
        '/api/admin/auth/daily?startDate=$startStr&endDate=$endStr',
      );
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    HapticFeedback.lightImpact();
    DateTime? tempStart = _selectedRange.start;
    DateTime? tempEnd = _selectedRange.end;

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
                    'Select a start and end date for the report.',
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
                                  'End date must be after start date.',
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Apply Filter',
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
      _selectedRange = DateTimeRange(start: tempStart!, end: tempEnd!);
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
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.cardBorder),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.calendar,
                  size: 16,
                  color: date != null
                      ? AppColors.primaryDark
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    date != null
                        ? '${date.day}/${date.month}/${date.year}'
                        : 'Select',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: date != null
                          ? FontWeight.w600
                          : FontWeight.w400,
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

  void _goDay(int offset) {
    final duration =
        _selectedRange.end.difference(_selectedRange.start).inDays + 1;
    final moveDays = offset * duration;
    final nextStart = _selectedRange.start.add(Duration(days: moveDays));
    final nextEnd = _selectedRange.end.add(Duration(days: moveDays));

    if (nextStart.isAfter(DateTime.now())) return;

    HapticFeedback.lightImpact();
    _selectedRange = DateTimeRange(
      start: nextStart,
      end: nextEnd.isAfter(DateTime.now()) ? DateTime.now() : nextEnd,
    );
    _load();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedRange.start.year == now.year &&
        _selectedRange.start.month == now.month &&
        _selectedRange.start.day == now.day &&
        _selectedRange.end.year == now.year &&
        _selectedRange.end.month == now.month &&
        _selectedRange.end.day == now.day;
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
            // ── App Bar ──
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
                'Daily Report',
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
                const SizedBox(width: 4),
              ],
            ),

            // ── Body ──
            if (_isLoading)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Date nav skeleton
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: const [
                          AppShimmer(width: 40, height: 40, borderRadius: 12),
                          Spacer(),
                          Column(
                            children: [
                              AppShimmer(width: 70, height: 14),
                              SizedBox(height: 4),
                              AppShimmer(width: 100, height: 11),
                            ],
                          ),
                          Spacer(),
                          AppShimmer(width: 40, height: 40, borderRadius: 12),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Hero card skeleton
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: const [
                                AppShimmer(
                                  width: 20,
                                  height: 20,
                                  borderRadius: 4,
                                ),
                                SizedBox(height: 8),
                                AppShimmer(width: 60, height: 22),
                                SizedBox(height: 4),
                                AppShimmer(width: 40, height: 11),
                                SizedBox(height: 8),
                                AppShimmer(
                                  width: 50,
                                  height: 18,
                                  borderRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 60,
                            color: AppColors.cardBorder,
                          ),
                          Expanded(
                            child: Column(
                              children: const [
                                AppShimmer(
                                  width: 20,
                                  height: 20,
                                  borderRadius: 4,
                                ),
                                SizedBox(height: 8),
                                AppShimmer(width: 80, height: 22),
                                SizedBox(height: 4),
                                AppShimmer(width: 50, height: 11),
                                SizedBox(height: 8),
                                AppShimmer(
                                  width: 50,
                                  height: 18,
                                  borderRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // KPI rows
                    for (int i = 0; i < 3; i++) ...[
                      Row(
                        children: [
                          Expanded(child: _dailyKpiSkeleton()),
                          const SizedBox(width: 10),
                          Expanded(child: _dailyKpiSkeleton()),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 10),
                    // Status chips skeleton
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (int i = 0; i < 4; i++)
                          AppShimmer(
                            width: 100 + (i * 10).toDouble(),
                            height: 38,
                            borderRadius: 14,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Products list skeleton
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < 4; i++)
                            Padding(
                              padding: EdgeInsets.only(bottom: i < 3 ? 12 : 0),
                              child: Row(
                                children: [
                                  AppShimmer(
                                    width: 28,
                                    height: 28,
                                    borderRadius: 8,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AppShimmer(
                                          width: 100 + (i * 15).toDouble(),
                                          height: 12,
                                        ),
                                        const SizedBox(height: 4),
                                        AppShimmer(
                                          width: double.infinity,
                                          height: 4,
                                          borderRadius: 3,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const AppShimmer(width: 30, height: 13),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ]),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(child: _buildError())
            else if (_data == null)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No data available',
                    style: GoogleFonts.inter(color: AppColors.textMuted),
                  ),
                ),
              )
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
          const SizedBox(height: 12),
          Text(
            'Failed to load report',
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
    final d = _data!;
    final growth = d['growth'] as Map<String, dynamic>? ?? {};
    final statusList = (d['statusBreakdown'] as List?) ?? [];
    final topProducts = (d['topProducts'] as List?) ?? [];
    final sources = (d['orderSources'] as List?) ?? [];
    final payments = (d['paymentMethods'] as List?) ?? [];
    final cities = (d['cityBreakdown'] as List?) ?? [];
    final recentOrders = (d['recentOrders'] as List?) ?? [];
    final totalOrders = (d['totalOrders'] as num?)?.toInt() ?? 0;
    final totalRevenue = (d['totalRevenue'] as num?)?.toDouble() ?? 0;
    final avgOrder = (d['averageOrderValue'] as num?)?.toDouble() ?? 0;
    final newCustomers = (d['newCustomers'] as num?)?.toInt() ?? 0;
    final revGrowth = (growth['revenueGrowth'] as num?)?.toDouble() ?? 0;
    final ordGrowth = (growth['ordersGrowth'] as num?)?.toDouble() ?? 0;
    final sot = d['sourceOfTruth'] as Map<String, dynamic>?;

    return [
      // ── Date Navigation ──
      _buildDateNav(),
      const SizedBox(height: 16),

      // ── Hero Summary ──
      _buildHeroCard(totalOrders, totalRevenue, revGrowth, ordGrowth),
      const SizedBox(height: 14),

      if (sot != null) ...[
        FinancialTruthHero(
          treasury: Map<String, dynamic>.from(sot['treasury'] as Map? ?? {}),
          audited: Map<String, dynamic>.from(sot['auditedOrders'] as Map? ?? {}),
          cashFlow: Map<String, dynamic>.from(sot['cashFlow'] as Map? ?? {}),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _kpiMini(
                'Cash in',
                fmtEgp((sot['cashFlow']?['periodIn'] as num?) ?? 0),
                LucideIcons.arrowDownLeft,
                AppColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _kpiMini(
                'Cash out',
                fmtEgp((sot['cashFlow']?['periodOut'] as num?) ?? 0),
                LucideIcons.arrowUpRight,
                AppColors.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],

      // ── KPI Row 1 ──
      Row(
        children: [
          Expanded(
            child: _kpiMini(
              'Avg Order',
              '${avgOrder.toStringAsFixed(0)} EGP',
              LucideIcons.calculator,
              const Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _kpiMini(
              'New Customers',
              '$newCustomers',
              LucideIcons.userPlus,
              const Color(0xFF0EA5E9),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),

      // ── KPI Row 2 (NEW) ──
      Row(
        children: [
          Expanded(
            child: _kpiMini(
              'Shipping',
              '${_fmt(d['shippingRevenue'])} EGP',
              LucideIcons.truck,
              const Color(0xFF059669),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _kpiMini(
              'Discounts',
              '${_fmt(d['discountsGiven'])} EGP',
              LucideIcons.tag,
              const Color(0xFFF97316),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),

      // ── KPI Row 3 (NEW) ──
      Row(
        children: [
          Expanded(
            child: _kpiMini(
              'Returns',
              '${d['returnsCount'] ?? 0}',
              LucideIcons.rotateCcw,
              const Color(0xFFDC2626),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: SizedBox()), // Empty slot
        ],
      ),
      const SizedBox(height: 20),

      // ── Status Breakdown ──
      if (statusList.isNotEmpty) ...[
        _sectionHeader(
          'ORDER STATUS',
          LucideIcons.pieChart,
          const Color(0xFF7C3AED),
        ),
        const SizedBox(height: 10),
        _buildStatusCards(statusList),
        const SizedBox(height: 20),
      ],

      // ── Top Products ──
      if (topProducts.isNotEmpty) ...[
        _sectionHeader('TOP PRODUCTS', LucideIcons.package2, AppColors.accent),
        const SizedBox(height: 10),
        _buildTopProducts(topProducts),
        const SizedBox(height: 20),
      ],

      // ── Order Sources ──
      if (sources.isNotEmpty) ...[
        _sectionHeader(
          'ORDER SOURCES',
          LucideIcons.globe,
          const Color(0xFF10B981),
        ),
        const SizedBox(height: 10),
        _buildHorizontalChips(
          sources,
          (s) => (s['source'] ?? 'unknown').toString().toUpperCase(),
          (s) => (s['count'] as num?)?.toInt() ?? 0,
          const Color(0xFF10B981),
        ),
        const SizedBox(height: 20),
      ],

      // ── Payment Methods ──
      if (payments.isNotEmpty) ...[
        _sectionHeader(
          'PAYMENT METHODS',
          LucideIcons.creditCard,
          const Color(0xFFF59E0B),
        ),
        const SizedBox(height: 10),
        _buildHorizontalChips(
          payments,
          (p) => (p['method'] ?? 'unknown').toString().toUpperCase(),
          (p) => (p['count'] as num?)?.toInt() ?? 0,
          const Color(0xFFF59E0B),
        ),
        const SizedBox(height: 20),
      ],

      // ── Cities ──
      if (cities.isNotEmpty) ...[
        _sectionHeader(
          'TOP CITIES',
          LucideIcons.mapPin,
          const Color(0xFF7C3AED),
        ),
        const SizedBox(height: 10),
        _buildCities(cities),
        const SizedBox(height: 20),
      ],

      // ── Recent Orders ──
      if (recentOrders.isNotEmpty) ...[
        _sectionHeader(
          'RECENT ORDERS',
          LucideIcons.shoppingBag,
          AppColors.info,
        ),
        const SizedBox(height: 10),
        ...recentOrders.take(10).map((o) => _buildOrderCard(o)),
      ],
    ];
  }

  // ── Date Navigation ──
  Widget _buildDateNav() {
    final bool isSingleDay =
        _selectedRange.start.year == _selectedRange.end.year &&
        _selectedRange.start.month == _selectedRange.end.month &&
        _selectedRange.start.day == _selectedRange.end.day;

    final String dayName;
    final String dateStr;

    if (isSingleDay) {
      dayName = _isToday
          ? 'Today'
          : DateFormat('EEEE').format(_selectedRange.start);
      dateStr = DateFormat('d MMM yyyy').format(_selectedRange.start);
    } else {
      final duration =
          _selectedRange.end.difference(_selectedRange.start).inDays + 1;
      dayName = '$duration Days';
      final startFmt = DateFormat('d MMM').format(_selectedRange.start);
      final endFmt = DateFormat('d MMM yyyy').format(_selectedRange.end);
      dateStr = '$startFmt - $endFmt';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          _navButton(LucideIcons.chevronLeft, () => _goDay(-1)),
          Expanded(
            child: GestureDetector(
              onTap: _pickDate,
              child: Column(
                children: [
                  Text(
                    dayName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _navButton(
            LucideIcons.chevronRight,
            _selectedRange.end.isAfter(
                  DateTime.now().subtract(const Duration(days: 1)),
                )
                ? null
                : () => _goDay(1),
          ),
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: onTap != null
              ? AppColors.primaryDark.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: onTap != null ? AppColors.primaryDark : AppColors.cardBorder,
        ),
      ),
    );
  }

  // ── Hero Card ──
  Widget _buildHeroCard(
    int orders,
    double revenue,
    double revGrowth,
    double ordGrowth,
  ) {
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
        children: [
          Row(
            children: [
              Expanded(
                child: _heroStat(
                  'Orders',
                  '$orders',
                  ordGrowth,
                  LucideIcons.shoppingBag,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              Expanded(
                child: _heroStat(
                  'Revenue',
                  '${revenue.toStringAsFixed(0)} EGP',
                  revGrowth,
                  LucideIcons.trendingUp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value, double growth, IconData icon) {
    final isUp = growth >= 0;
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.accent),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (isUp ? AppColors.success : AppColors.error).withValues(
              alpha: 0.2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isUp ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                size: 10,
                color: isUp ? const Color(0xFF4ADE80) : const Color(0xFFFCA5A5),
              ),
              const SizedBox(width: 3),
              Text(
                '${growth.abs().toStringAsFixed(1)}%',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isUp
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFFFCA5A5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── KPI Mini ──
  Widget _kpiMini(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Header ──
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

  // ── Status Cards ──
  Widget _buildStatusCards(List<dynamic> statuses) {
    final total = statuses.fold<int>(
      0,
      (sum, s) => sum + ((s['count'] as num?)?.toInt() ?? 0),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statuses.map((s) {
        final status = (s['status'] ?? '').toString();
        final count = (s['count'] as num?)?.toInt() ?? 0;
        final color = _statusColor(status);
        final pct = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                status.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                ' ($pct%)',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Top Products ──
  Widget _buildTopProducts(List<dynamic> products) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: products.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          final isTop3 = i < 3;
          final qty = (p['quantity'] as num?)?.toInt() ?? 0;
          final maxQty = (products[0]['quantity'] as num?)?.toInt() ?? 1;
          return Padding(
            padding: EdgeInsets.only(bottom: i < products.length - 1 ? 12 : 0),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isTop3
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : AppColors.cardBorder.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isTop3 ? AppColors.accent : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['name'] ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isTop3
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: maxQty > 0 ? qty / maxQty : 0,
                          minHeight: 4,
                          backgroundColor: AppColors.cardBorder,
                          color: isTop3
                              ? AppColors.accent
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '×$qty',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Horizontal Chips ──
  Widget _buildHorizontalChips(
    List<dynamic> items,
    String Function(dynamic) getLabel,
    int Function(dynamic) getCount,
    Color color,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                getLabel(item),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${getCount(item)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Cities ──
  Widget _buildCities(List<dynamic> cities) {
    final maxCount = cities.isNotEmpty
        ? ((cities[0]['count'] as num?)?.toInt() ?? 1)
        : 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: cities.map((c) {
          final count = (c['count'] as num?)?.toInt() ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.mapPin,
                          size: 12,
                          color: Color(0xFF7C3AED),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          c['city'] ?? 'Unknown',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$count orders',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: count / maxCount,
                    minHeight: 4,
                    backgroundColor: AppColors.cardBorder,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Order Card ──
  Widget _buildOrderCard(dynamic order) {
    final status = (order['status'] ?? '').toString();
    final color = _statusColor(status);
    final time = DateTime.tryParse(order['time'] ?? '');
    final timeStr = time != null ? DateFormat('h:mm a').format(time) : '';

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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '#${order['orderNumber'] ?? ''}',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order['customer'] ?? 'Guest',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${order['itemCount'] ?? 0} items · $timeStr',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(order['total'] as num?)?.toStringAsFixed(0) ?? '0'} EGP',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return AppColors.warning;
      case 'PROCESSING':
        return AppColors.info;
      case 'SHIPPED':
        return const Color(0xFF7C3AED);
      case 'DELIVERED':
        return AppColors.success;
      case 'CANCELLED':
        return AppColors.error;
      case 'REJECTED':
        return AppColors.error;
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

  Widget _dailyKpiSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const AppShimmer(width: 32, height: 32, borderRadius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                AppShimmer(width: 60, height: 14),
                SizedBox(height: 4),
                AppShimmer(width: 40, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
