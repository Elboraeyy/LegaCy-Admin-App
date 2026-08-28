import 'package:flutter/material.dart';
import 'package:admin_app/core/widgets/app_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/features/notifications/notification_provider.dart';
import 'package:admin_app/features/orders/orders_screen.dart';
import 'package:admin_app/features/operations/screens/inventory_screen.dart';
import 'package:admin_app/features/more/screens/reviews_screen.dart';
import 'package:admin_app/features/more/screens/messages_screen.dart';
import 'package:admin_app/features/more/screens/stock_requests_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  String _filter = 'all'; // all, unread, order, inventory, review, message

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    // Refresh notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  List<AppNotification> _getFiltered(NotificationProvider provider) {
    var list = provider.notifications;
    if (_filter == 'unread') {
      list = list.where((n) => !n.isRead).toList();
    } else if (_filter != 'all') {
      list = list.where((n) => n.category == _filter).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: () => context.read<NotificationProvider>().fetchNotifications(),
            color: AppColors.primaryDark,
            child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Premium App Bar ──
              SliverAppBar(
                pinned: true,
                expandedHeight: 130,
                backgroundColor: AppColors.surface,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.arrowLeft,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  if (provider.hasUnread)
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        provider.markAllAsRead();
                      },
                      icon: const Icon(
                        LucideIcons.checkCheck,
                        size: 16,
                        color: AppColors.primaryDark,
                      ),
                      label: Text(
                        'Read All',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  if (provider.notifications.isNotEmpty)
                    PopupMenuButton<String>(
                      icon: const Icon(
                        LucideIcons.moreVertical,
                        color: AppColors.primaryDark,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onSelected: (v) {
                        if (v == 'clear') {
                          _confirmClearAll(provider);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'clear',
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.trash2,
                                size: 16,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Clear All',
                                style: GoogleFonts.inter(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                  title: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      if (provider.unreadCount > 0)
                        Text(
                          '${provider.unreadCount} unread',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Filter Chips ──
              SliverToBoxAdapter(
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildFilterChip('All', 'all', LucideIcons.bell),
                      _buildFilterChip(
                        'Unread',
                        'unread',
                        LucideIcons.mailOpen,
                      ),
                      _buildFilterChip(
                        'Orders',
                        'order',
                        LucideIcons.shoppingBag,
                      ),
                      _buildFilterChip(
                        'Stock',
                        'inventory',
                        LucideIcons.alertTriangle,
                      ),
                      _buildFilterChip('Reviews', 'review', LucideIcons.star),
                      _buildFilterChip('Messages', 'message', LucideIcons.mail),
                    ],
                  ),
                ),
              ),

              // ── Loading State ──
              if (provider.isLoading)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppShimmer(width: 44, height: 44, borderRadius: 12),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppShimmer(width: 150, height: 14, borderRadius: 4),
                                  const SizedBox(height: 6),
                                  AppShimmer(width: 200, height: 12, borderRadius: 4),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      AppShimmer(width: 50, height: 10, borderRadius: 4),
                                      const Spacer(),
                                      AppShimmer(width: 60, height: 10, borderRadius: 4),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      childCount: 6,
                    ),
                  ),
                )
              // ── Empty State ──
              else if (_getFiltered(provider).isEmpty)
                SliverFillRemaining(child: _buildEmptyState())
              // ── Notification List ──
              else
                ..._buildGroupedList(provider),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          );
        },
      ),
    );
  }

  List<Widget> _buildGroupedList(NotificationProvider provider) {
    final filtered = _getFiltered(provider);
    final List<Widget> slivers = [];

    // Group by date
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayItems = filtered
        .where(
          (n) =>
              n.createdAt.isAfter(today) || n.createdAt.isAtSameMomentAs(today),
        )
        .toList();

    final yesterdayItems = filtered
        .where(
          (n) => n.createdAt.isAfter(yesterday) && n.createdAt.isBefore(today),
        )
        .toList();

    final earlierItems = filtered
        .where((n) => n.createdAt.isBefore(yesterday))
        .toList();

    if (todayItems.isNotEmpty) {
      slivers.add(_buildSectionHeader('Today', todayItems.length));
      slivers.add(_buildNotificationSliver(todayItems, provider));
    }
    if (yesterdayItems.isNotEmpty) {
      slivers.add(_buildSectionHeader('Yesterday', yesterdayItems.length));
      slivers.add(_buildNotificationSliver(yesterdayItems, provider));
    }
    if (earlierItems.isNotEmpty) {
      slivers.add(_buildSectionHeader('Earlier', earlierItems.length));
      slivers.add(_buildNotificationSliver(earlierItems, provider));
    }

    return slivers;
  }

  Widget _buildSectionHeader(String title, int count) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSliver(
    List<AppNotification> items,
    NotificationProvider provider,
  ) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        return FadeTransition(
          opacity: _fadeAnim,
          child: _NotificationTile(
            notification: items[index],
            onTap: () => _handleNotificationTap(items[index], provider),
            onDismiss: () => provider.deleteNotification(items[index].id),
          ),
        );
      }, childCount: items.length),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _filter = value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primaryDark : AppColors.cardBorder,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _filter == 'unread'
                    ? LucideIcons.checkCheck
                    : LucideIcons.bellOff,
                size: 48,
                color: AppColors.accent.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _filter == 'unread' ? 'All caught up!' : 'No notifications',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _filter == 'unread'
                  ? 'You\'ve read all your notifications.'
                  : 'New notifications for orders, reviews,\nand alerts will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNotificationTap(
    AppNotification notification,
    NotificationProvider provider,
  ) {
    HapticFeedback.lightImpact();
    provider.markAsRead(notification.id);

    Widget? targetScreen;
    switch (notification.category) {
      case 'order':
        targetScreen = const OrdersScreen();
        break;
      case 'inventory':
        targetScreen = const InventoryScreen();
        break;
      case 'review':
        targetScreen = const ReviewsListScreen();
        break;
      case 'message':
        targetScreen = const MessagesListScreen();
        break;
      case 'restock':
        targetScreen = const StockRequestsScreen();
        break;
      default:
        return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => targetScreen!));
  }

  void _confirmClearAll(NotificationProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(LucideIcons.alertCircle, color: Colors.red, size: 22),
            const SizedBox(width: 10),
            Text(
              'Clear All?',
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
        content: Text(
          'This will permanently remove all notifications. This action cannot be undone.',
          style: GoogleFonts.inter(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.clearAll();
              HapticFeedback.mediumImpact();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Clear All',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual Notification Tile ──
class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        HapticFeedback.lightImpact();
        onDismiss();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(LucideIcons.trash2, color: Colors.red, size: 20),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead ? Colors.white : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead
                  ? AppColors.cardBorder
                  : notification.color.withValues(alpha: 0.2),
            ),
            boxShadow: notification.isRead
                ? []
                : [
                    BoxShadow(
                      color: notification.color.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: notification.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  notification.icon,
                  size: 20,
                  color: notification.color,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              color: notification.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: notification.isRead
                            ? AppColors.textMuted
                            : AppColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Category badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: notification.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _categoryLabel(notification.category),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: notification.color,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Time
                        Icon(
                          LucideIcons.clock,
                          size: 11,
                          color: AppColors.textMuted.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(notification.createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'order':
        return 'ORDER';
      case 'inventory':
        return 'STOCK';
      case 'review':
        return 'REVIEW';
      case 'message':
        return 'MESSAGE';
      case 'restock':
        return 'RESTOCK';
      case 'finance':
        return 'FINANCE';
      default:
        return 'SYSTEM';
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(dt);
  }
}
