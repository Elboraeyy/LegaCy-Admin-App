import 'package:admin_app/core/services/app_image_cache_manager.dart';
import 'package:admin_app/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/core/services/unread_tracker.dart';

import 'screens/reviews_screen.dart';
import 'screens/messages_screen.dart';
import '../marketing/screens/promotions_screen.dart';
import '../settings/screens/notifications_settings_screen.dart';
import '../operations/screens/inventory_screen.dart';
import '../operations/screens/delivery_zones_screen.dart';
import '../operations/screens/procurement_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/stock_requests_screen.dart';
import '../finance/screens/treasury_screen.dart';
import '../finance/screens/orders_audit_screen.dart';
import '../finance/screens/expenses_screen.dart';
import '../finance/screens/month_closing_screen.dart';
import '../finance/screens/partner_wallet_screen.dart';
import '../finance/screens/finance_approvals_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  bool _isUploadingAvatar = false;
  int _newReviewsCount = 0;
  int _newMessagesCount = 0;
  int _newRestockCount = 0;
  int _newApprovalsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) return;
      final client = ApiClient(token: token);

      final results = await Future.wait([
        client
            .get('/api/admin/auth/reviews')
            .catchError((_) => {'reviews': []}),
        client
            .get('/api/admin/auth/messages')
            .catchError((_) => {'messages': []}),
        client
            .get('/api/admin/auth/stock-requests')
            .catchError((_) => {'requests': []}),
        client
            .get('/api/admin/auth/finance/withdrawals')
            .catchError((_) => {'withdrawals': []}),
      ]);

      if (mounted) {
        setState(() {
          // For reviews, count those not featured, created in the last 7 days and not read yet
          final reviews = results[0]['reviews'] as List?;
          _newReviewsCount =
              reviews?.where((r) {
                final id = r['id'] as String?;
                if (id == null) return false;
                if (r['featured'] == true) return false;
                if (UnreadTracker.isRead('review', id)) return false;
                if (r['createdAt'] != null) {
                  final dt = DateTime.tryParse(r['createdAt']);
                  if (dt != null && DateTime.now().difference(dt).inDays <= 7)
                    return true;
                }
                return false;
              }).length ??
              0;

          // For messages, status NEW means unread
          _newMessagesCount =
              (results[1]['messages'] as List?)
                  ?.where((m) => m['status'] == 'NEW')
                  .length ??
              0;

          // For stock requests, status pending means waiting and not read yet
          _newRestockCount =
              (results[2]['requests'] as List?)
                  ?.where((r) {
                    final id = r['id'] as String?;
                    if (id == null) return false;
                    return r['status'] == 'pending' && !UnreadTracker.isRead('restock', id);
                  })
                  .length ??
              0;

          // For approvals, status PENDING and not read yet
          _newApprovalsCount =
              (results[3]['withdrawals'] as List?)
                  ?.where((w) {
                    final id = w['id'] as String?;
                    if (id == null) return false;
                    return w['status'] == 'PENDING' && !UnreadTracker.isRead('approval', id);
                  })
                  .length ??
              0;
        });
      }
    } catch (e) {
      // Ignore errors for badges
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;

    if (!mounted) return;
    setState(() => _isUploadingAvatar = true);

    try {
      final auth = context.read<AuthProvider>();
      final client = ApiClient(token: auth.token);

      // Upload to Cloudinary via backend
      final uploadRes = await client.uploadMultipart(
        '/api/admin/auth/upload',
        filePath: file.path,
        fileField: 'file',
        fields: {'folder': 'avatars'},
      );
      final imageUrl = uploadRes['url'];

      // Update Staff profile
      final userId = auth.user?['id'];
      if (userId != null && imageUrl != null) {
        await client.put(
          '/api/admin/auth/staff/$userId',
          body: {'avatar': imageUrl},
        );

        auth.updateAvatar(imageUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showAppToast(
            AppToast.snackBar(
              content: Text('Profile picture updated successfully'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppToast(
          AppToast.snackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final adminName = auth.adminName ?? 'Admin';
    final initial = adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A';
    final String? avatarUrl = auth.user?['avatar'];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadBadges,
        color: AppColors.primaryDark,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          // Clean Standard Header
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            titleSpacing: 20,
            title: Text(
              'Menu',
              style: GoogleFonts.playfairDisplay(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Clean Green Profile Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryDark, Color(0xFF1E5C56)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryDark.withValues(alpha: 0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppColors.surface, // White circle
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _isUploadingAvatar
                                  ? const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(
                                        color: AppColors.primaryDark,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : avatarUrl != null && avatarUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      cacheManager:
                                          AppImageCacheManager.instance,
                                      imageUrl: avatarUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.primaryDark,
                                            ),
                                          ),
                                      errorWidget: (context, url, error) =>
                                          Center(
                                            child: Text(
                                              initial,
                                              style:
                                                  GoogleFonts.playfairDisplay(
                                                    fontSize: 26,
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        AppColors.primaryDark,
                                                  ),
                                            ),
                                          ),
                                    )
                                  : Center(
                                      child: Text(
                                        initial,
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    ),
                            ),
                            Positioned(
                              bottom: -2,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primaryDark,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  LucideIcons.camera,
                                  size: 10,
                                  color: Colors.white,
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
                              adminName,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.shieldCheck,
                                    size: 12,
                                    color: AppColors.accentLight,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Super Admin',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.accentLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                _buildSection(
                  title: 'Partner Area',
                  icon: LucideIcons.users,
                  items: [
                    _MenuItem(
                      title: 'My Wallet',
                      subtitle: 'Earnings & withdrawals',
                      icon: LucideIcons.wallet,
                      color: const Color(0xFF10B981),
                      screen: const PartnerWalletScreen(),
                    ),
                    if (auth.role == 'SUPER_ADMIN' || auth.role == 'owner' || auth.role == 'super_admin')
                      _MenuItem(
                        title: 'Approvals',
                        subtitle: 'Partner withdrawals',
                        icon: LucideIcons.checkCircle2,
                        color: const Color(0xFFF59E0B),
                        screen: const FinanceApprovalsScreen(),
                        badge: _newApprovalsCount > 0
                            ? _newApprovalsCount.toString()
                            : null,
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                _buildSection(
                  title: 'Audience & Engagement',
                  icon: LucideIcons.heart,
                  items: [
                    _MenuItem(
                      title: 'Promos & Discounts',
                      subtitle: 'Coupons, BOGO & flash sales',
                      icon: LucideIcons.badgePercent,
                      color: const Color(0xFFEF4444),
                      screen: const PromotionsScreen(),
                    ),
                    _MenuItem(
                      title: 'Customers',
                      subtitle: 'Client CRM & history',
                      icon: LucideIcons.userCheck,
                      color: const Color(0xFF10B981),
                      screen: const CustomersListScreen(),
                    ),
                    _MenuItem(
                      title: 'Reviews',
                      subtitle: 'Moderate product reviews',
                      icon: LucideIcons.star,
                      color: const Color(0xFFF59E0B),
                      screen: const ReviewsListScreen(),
                      badge: _newReviewsCount > 0
                          ? _newReviewsCount.toString()
                          : null,
                    ),
                    _MenuItem(
                      title: 'Messages',
                      subtitle: 'Contact form submissions',
                      icon: LucideIcons.mail,
                      color: const Color(0xFF6366F1),
                      screen: const MessagesListScreen(),
                      badge: _newMessagesCount > 0
                          ? _newMessagesCount.toString()
                          : null,
                    ),
                    _MenuItem(
                      title: 'Restock Requests',
                      subtitle: 'Waitlists and back in stock',
                      icon: LucideIcons.bellRing,
                      color: const Color(0xFF0EA5E9),
                      screen: const StockRequestsScreen(),
                      badge: _newRestockCount > 0
                          ? _newRestockCount.toString()
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                _buildSection(
                  title: 'Operations',
                  icon: LucideIcons.truck,
                  items: [
                    _MenuItem(
                      title: 'Inventory',
                      subtitle: 'Stock control & alerts',
                      icon: LucideIcons.package,
                      color: const Color(0xFF64748B),
                      screen: const InventoryScreen(),
                    ),
                    _MenuItem(
                      title: 'Procurement',
                      subtitle: 'Supplier orders',
                      icon: LucideIcons.shoppingBag,
                      color: const Color(0xFF8B5CF6),
                      screen: const ProcurementScreen(),
                    ),
                    _MenuItem(
                      title: 'Delivery Zones',
                      subtitle: 'Shipping rates & rules',
                      icon: LucideIcons.map,
                      color: const Color(0xFF0EA5E9),
                      screen: const DeliveryZonesScreen(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (auth.role == 'SUPER_ADMIN' || auth.role == 'owner' || auth.role == 'super_admin') ...[
                  _buildSection(
                    title: 'Finance & Analytics',
                    icon: LucideIcons.pieChart,
                    items: [
                      _MenuItem(
                        title: 'Treasury & Safes',
                        subtitle: 'Cash, bank & wallets',
                        icon: LucideIcons.landmark,
                        color: const Color(0xFF059669),
                        screen: const TreasuryScreen(),
                      ),
                      _MenuItem(
                        title: 'Orders Audit',
                        subtitle: 'P&L tracking per order',
                        icon: LucideIcons.clipboardCheck,
                        color: const Color(0xFF3B82F6),
                        screen: const OrdersAuditScreen(),
                      ),
                      _MenuItem(
                        title: 'Expenses',
                        subtitle: 'Operating costs & ads',
                        icon: LucideIcons.receipt,
                        color: const Color(0xFFDC2626),
                        screen: const ExpensesScreen(),
                      ),
                      _MenuItem(
                        title: 'Month Closing',
                        subtitle: 'P&L & profit sharing',
                        icon: LucideIcons.calendarCheck,
                        color: const Color(0xFF8B5CF6),
                        screen: const MonthClosingScreen(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                _buildSection(
                  title: 'System Settings',
                  icon: LucideIcons.settings,
                  items: [
                    _MenuItem(
                      title: 'Notifications',
                      subtitle: 'Push alerts setup',
                      icon: LucideIcons.bellRing,
                      color: const Color(0xFFD946EF),
                      screen: const NotificationsSettingsScreen(),
                    ),
                    _MenuItem(
                      title: 'Web Dashboard',
                      subtitle: 'Open legecy.store/admin',
                      icon: LucideIcons.globe,
                      color: AppColors.primaryDark,
                      onTap: () async {
                        final uri = Uri.parse('https://www.legecy.store/admin');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Logout Button
                _buildActionCard(
                  context,
                  title: 'Sign Out',
                  subtitle: 'Securely end your session',
                  icon: LucideIcons.logOut,
                  color: AppColors.error,
                  onTap: () => _confirmLogout(context),
                  isDestructive: true,
                ),
                const SizedBox(height: 32),

                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.textMuted.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Legacy Admin Hub',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Version 1.0.0 • Production',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<_MenuItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardBorder.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  _MenuItemWidget(item: item, onReturn: _loadBadges),
                  if (index < items.length - 1)
                    Divider(height: 1, indent: 64, color: AppColors.divider),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDestructive
              ? color.withValues(alpha: 0.05)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDestructive
                ? color.withValues(alpha: 0.2)
                : AppColors.cardBorder,
          ),
          boxShadow: isDestructive
              ? []
              : [
                  BoxShadow(
                    color: AppColors.cardBorder.withValues(alpha: 0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? color : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDestructive
                          ? color.withValues(alpha: 0.8)
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: isDestructive
                  ? color.withValues(alpha: 0.5)
                  : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(LucideIcons.alertCircle, color: AppColors.error),
            const SizedBox(width: 12),
            Text(
              'Sign Out',
              style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to end your secure session? You will need to log in again.',
          style: GoogleFonts.inter(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Sign Out',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget? screen;
  final VoidCallback? onTap;
  final String? badge;

  _MenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.screen,
    this.onTap,
    this.badge,
  });
}

class _MenuItemWidget extends StatelessWidget {
  final _MenuItem item;
  final VoidCallback? onReturn;

  const _MenuItemWidget({required this.item, this.onReturn});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          if (item.onTap != null) {
            item.onTap!();
          } else if (item.screen != null) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => item.screen!),
            );
            if (onReturn != null) {
              onReturn!();
            }
          }
        },
        highlightColor: item.color.withValues(alpha: 0.05),
        splashColor: item.color.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 18, color: item.color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.title,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (item.badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: item.color,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.badge!,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: AppColors.textMuted.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

