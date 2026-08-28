import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:admin_app/features/dashboard/dashboard_widgets.dart';
import 'package:admin_app/features/dashboard/providers/todo_provider.dart';
import 'package:admin_app/features/dashboard/widgets/todo_widgets.dart';
import 'package:admin_app/features/dashboard/screens/add_todo_dialog.dart';
import 'package:admin_app/features/reports/daily_report_screen.dart';
import 'package:admin_app/features/reports/statistics_screen.dart';
import 'package:admin_app/features/notifications/notification_provider.dart';
import 'package:admin_app/features/notifications/notifications_screen.dart';
import 'package:admin_app/features/operations/screens/inventory_screen.dart';
import 'package:admin_app/features/marketing/screens/coupons_screen.dart';

import 'package:admin_app/features/products/add_product_screen.dart';

import 'package:admin_app/features/orders/order_details_screen.dart';
import 'package:admin_app/features/orders/create_manual_order_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _loadData();
    _loadTodos();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final data = await client.get('/api/admin/auth/dashboard');
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
        _fadeController.forward(from: 0);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
      if (e.isUnauthorized && mounted) context.read<AuthProvider>().logout();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not connect to the server';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTodos() async {
    if (!mounted) return;
    try {
      final token = context.read<AuthProvider>().token;
      if (token != null) {
        await context.read<TodoProvider>().loadTodos(token);
      }
    } catch (e) {
      // Silent fail
    }
  }

  // Helper getters
  int _int(String key) => (_data?[key] as num?)?.toInt() ?? 0;
  double _dbl(String key) => (_data?[key] as num?)?.toDouble() ?? 0;
  List<Map<String, dynamic>> _list(String key) =>
      List<Map<String, dynamic>>.from(_data?[key] ?? []);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primaryDark,
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── App Bar ──
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.background,
              surfaceTintColor: Colors.transparent,
              expandedHeight: 110,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(
                  left: 20,
                  bottom: 20,
                  right: 20,
                ),
                title: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Greeting with gold color
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: _getGreeting(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.5,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          auth.adminName ?? 'Admin',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Consumer<NotificationProvider>(
                    builder: (context, notifProvider, _) {
                      final count = notifProvider.unreadCount;
                      return IconButton(
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(
                              LucideIcons.bell,
                              size: 24,
                              color: AppColors.primaryDark,
                            ),
                            if (count > 0)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.error,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.background,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.error.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    count > 99 ? '99+' : '$count',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 1.0,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // ── Content ──
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_isLoading)
                    const DashboardShimmer()
                  else if (_error != null)
                    _buildError()
                  else
                    FadeTransition(opacity: _fadeAnim, child: _buildContent()),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.wifiOff,
                size: 32,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final recentOrders = _list('recentOrders');
    final topProducts = _list('topProducts');
    final weeklyChart = _list('weeklyChart');
    final todos = context.watch<TodoProvider>().allTodos;
    final auth = context.watch<AuthProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Live Status Badge ──
        _buildLiveStatus(),
        const SizedBox(height: 16),

        // ── TODO List Section ──
        TodoListSection(
          todos: todos,
          onAddTodo: () {
            showDialog(
              context: context,
              builder: (_) => AddTodoDialog(
                onAdd: (title, description, deadline) async {
                  await context.read<TodoProvider>().addTodo(
                    title: title,
                    description: description,
                    deadline: deadline,
                    adminName: auth.adminName ?? 'Admin',
                    token: auth.token,
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        // ── Quick Actions ──
        const DashboardSectionHeader(title: 'QUICK ACTIONS'),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              QuickActionButton(
                icon: LucideIcons.filePlus2,
                label: 'Manual\nOrder',
                color: AppColors.primaryDark,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateManualOrderScreen(),
                  ),
                ),
              ),
              QuickActionButton(
                icon: LucideIcons.plusCircle,
                label: 'New\nProduct',
                color: const Color(0xFF10B981),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddProductScreen()),
                ),
              ),
              QuickActionButton(
                icon: LucideIcons.warehouse,
                label: 'Inventory',
                color: _int('lowStockCount') > 0
                    ? AppColors.error
                    : const Color(0xFF0EA5E9),
                badge: _int('lowStockCount') > 0
                    ? '${_int('lowStockCount')}'
                    : null,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InventoryScreen()),
                ),
              ),
              QuickActionButton(
                icon: LucideIcons.ticket,
                label: 'Coupons',
                color: const Color(0xFFF59E0B),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CouponsScreen()),
                ),
              ),
              QuickActionButton(
                icon: LucideIcons.calendarDays,
                label: 'Daily\nReport',
                color: const Color(0xFF0EA5E9),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DailyReportScreen()),
                ),
              ),
              QuickActionButton(
                icon: LucideIcons.barChart3,
                label: 'Analytics',
                color: const Color(0xFF8B5CF6),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StatisticsScreen()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Stats Grid (2×2) ──
        Row(
          children: [
            Expanded(
              child: StatCardWithTrend(
                label: "Today's Orders",
                value: '${_int('todayOrders')}',
                icon: LucideIcons.shoppingBag,
                color: AppColors.info,
                changePercent: _int('ordersChange'),
                subtitle: 'vs yesterday: ${_int('yesterdayOrders')}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCardWithTrend(
                label: 'Revenue',
                value: '${_dbl('todayRevenue').toStringAsFixed(0)} EGP',
                icon: LucideIcons.trendingUp,
                color: AppColors.success,
                changePercent: _int('revenueChange'),
                subtitle:
                    'vs yesterday: ${_dbl('yesterdayRevenue').toStringAsFixed(0)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCardWithTrend(
                label: 'Total Products',
                value: '${_int('totalProducts')}',
                icon: LucideIcons.package2,
                color: const Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCardWithTrend(
                label: 'Low Stock',
                value: '${_int('lowStockCount')}',
                icon: LucideIcons.alertTriangle,
                color: _int('lowStockCount') > 0
                    ? AppColors.error
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Order Pipeline ──
        OrderPipeline(
          pending: _int('pendingOrders'),
          processing: _int('processingOrders'),
          shipped: _int('shippedOrders'),
          delivered: _int('deliveredOrders'),
        ),
        const SizedBox(height: 24),

        // ── Revenue Chart ──
        RevenueChart(data: weeklyChart),
        const SizedBox(height: 24),

        // ── Monthly Overview ──
        MonthlyOverviewCard(
          monthlyRevenue: _dbl('monthlyRevenue'),
          totalOrders: _int('totalOrdersThisMonth'),
          totalCustomers: _int('totalCustomers'),
          newCustomersToday: _int('newCustomersToday'),
        ),
        const SizedBox(height: 24),

        // ── Top Products ──
        if (topProducts.isNotEmpty) ...[
          const DashboardSectionHeader(
            title: 'TOP SELLING PRODUCTS',
            trailing: 'Last 30 days',
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: topProducts.asMap().entries.map((e) {
                return Column(
                  children: [
                    TopProductItem(
                      rank: e.key + 1,
                      name: e.value['name'] ?? 'Unknown',
                      totalSold: (e.value['totalSold'] as num?)?.toInt() ?? 0,
                      orderCount: (e.value['orderCount'] as num?)?.toInt() ?? 0,
                    ),
                    if (e.key < topProducts.length - 1)
                      Divider(height: 1, indent: 60, color: AppColors.divider),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // ── Recent Orders ──
        DashboardSectionHeader(
          title: 'RECENT ORDERS',
          trailing: '${recentOrders.length} orders',
        ),
        ...recentOrders.map((order) => _recentOrderCard(order)),
        const SizedBox(height: 24),

        // ── Order Status Breakdown ──
        _buildStatusBreakdown(),
        const SizedBox(height: 160),
      ],
    );
  }

  Widget _buildLiveStatus() {
    final now = DateTime.now();
    final formatted = DateFormat('EEE, d MMM · h:mm a').format(now);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Store Online',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.success,
            ),
          ),
          const Spacer(),
          Text(
            formatted,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBreakdown() {
    final raw = _data?['statusBreakdown'] as Map<String, dynamic>? ?? {};
    if (raw.isEmpty) return const SizedBox.shrink();

    final statusColors = <String, Color>{
      'pending': AppColors.warning,
      'processing': AppColors.info,
      'shipped': const Color(0xFF7C3AED),
      'delivered': AppColors.success,
      'cancelled': AppColors.error,
      'returned': const Color(0xFF64748B),
    };

    final total = raw.values.fold<int>(
      0,
      (s, v) => s + ((v as num?)?.toInt() ?? 0),
    );
    if (total == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardSectionHeader(title: 'ORDER STATUS BREAKDOWN'),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: raw.entries
                        .where((e) => (e.value as num).toInt() > 0)
                        .map((e) {
                          final count = (e.value as num).toInt();
                          final color =
                              statusColors[e.key] ?? AppColors.textMuted;
                          return Expanded(
                            flex: count,
                            child: Container(color: color),
                          );
                        })
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Legend
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: raw.entries
                    .where((e) => (e.value as num).toInt() > 0)
                    .map((e) {
                      final count = (e.value as num).toInt();
                      final color = statusColors[e.key] ?? AppColors.textMuted;
                      final pct = (count / total * 100).toStringAsFixed(0);
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${e.key[0].toUpperCase()}${e.key.substring(1)} ($count · $pct%)',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    })
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _recentOrderCard(Map<String, dynamic> order) {
    final status = (order['status'] ?? '').toString();
    final statusColors = <String, Color>{
      'pending': AppColors.warning,
      'processing': AppColors.info,
      'shipped': const Color(0xFF7C3AED),
      'delivered': AppColors.success,
      'cancelled': AppColors.error,
    };
    final statusColor =
        statusColors[status.toLowerCase()] ?? AppColors.textMuted;

    final createdAt = DateTime.tryParse(order['createdAt'] ?? '');
    final timeStr = createdAt != null ? _timeAgo(createdAt) : '';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailsScreen(orderId: order['id'] ?? ''),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '#${order['orderNumber'] ?? ''}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order['displayName'] ?? 'Guest',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${order['itemCount'] ?? 0} items · ${(order['totalPrice'] as num?)?.toStringAsFixed(0) ?? '0'} EGP',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (timeStr.isNotEmpty) ...[
                        Text(
                          ' · ',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          timeStr,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (order['governorate'] != null &&
                      (order['governorate'] as String).isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.mapPin,
                          size: 10,
                          color: AppColors.textMuted.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          order['governorate'],
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _sourceIcon(order['orderSource'] ?? ''),
                    const SizedBox(width: 3),
                    _paymentIcon(order['paymentMethod'] ?? ''),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceIcon(String source) {
    IconData icon;
    Color color;
    switch (source.toLowerCase()) {
      case 'online':
      case 'website':
        icon = LucideIcons.globe;
        color = AppColors.info;
        break;
      case 'manual':
        icon = LucideIcons.pencil;
        color = AppColors.accent;
        break;
      case 'pos':
        icon = LucideIcons.monitor;
        color = const Color(0xFF8B5CF6);
        break;
      default:
        icon = LucideIcons.shoppingBag;
        color = AppColors.textMuted;
    }
    return Icon(icon, size: 12, color: color.withValues(alpha: 0.6));
  }

  Widget _paymentIcon(String method) {
    IconData icon;
    switch (method.toLowerCase()) {
      case 'cod':
        icon = LucideIcons.banknote;
        break;
      case 'card':
        icon = LucideIcons.creditCard;
        break;
      case 'wallet':
        icon = LucideIcons.wallet;
        break;
      default:
        icon = LucideIcons.circleDollarSign;
    }
    return Icon(
      icon,
      size: 12,
      color: AppColors.textMuted.withValues(alpha: 0.6),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(dt);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}
