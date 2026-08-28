import 'package:admin_app/core/services/app_image_cache_manager.dart';
import 'package:admin_app/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:admin_app/features/orders/create_manual_order_screen.dart';
import 'package:admin_app/core/constants/order_constants.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:arabic_reshaper/arabic_reshaper.dart';
import 'package:gal/gal.dart';
import 'dart:ui' as ui;
import '../../core/widgets/app_shimmer.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  Map<String, dynamic>? _order;
  bool _isLoading = true;
  bool _isUpdating = false;
  final _noteController = TextEditingController();
  bool _isAddingNote = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() => _isLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final data = await client.get('/api/admin/auth/orders/${widget.orderId}');
      if (mounted) {
        setState(() {
          _order = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    HapticFeedback.mediumImpact();
    setState(() => _isUpdating = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      await client.patch(
        '/api/admin/auth/orders/${widget.orderId}',
        body: {'status': newStatus},
      );
      await _loadOrder();
      if (mounted) {
        ScaffoldMessenger.of(context).showAppToast(
          AppToast.snackBar(
            content: Text('Status updated to $newStatus'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppToast(
          AppToast.snackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Color _statusColorFor(String status) {
    switch (status.toLowerCase()) {
      case 'payment_pending':
        return const Color(0xFF7C3AED);
      case 'pending':
        return const Color(0xFFB76E00);
      case 'paid':
        return const Color(0xFF166534);
      case 'confirmed':
        return const Color(0xFF166534);
      case 'preparing':
        return const Color(0xFF0D9488);
      case 'shipped':
        return const Color(0xFF1E40AF);
      case 'delivered':
        return const Color(0xFF166534);
      case 'cancelled':
        return const Color(0xFF991B1B);
      case 'refunded':
        return const Color(0xFFCA8A04);
      case 'payment_failed':
        return const Color(0xFF991B1B);
      case 'cash_received':
        return const Color(0xFF166534);
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            _order != null ? '#${_order!['orderNumber']}' : 'Order Details',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppColors.background,
          elevation: 0,
          centerTitle: true,
          actions: [
            if (_order != null) ...[
              IconButton(
                icon: const Icon(
                  LucideIcons.edit,
                  color: AppColors.primaryDark,
                  size: 20,
                ),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CreateManualOrderScreen(existingOrder: _order),
                    ),
                  );
                  if (result == true) {
                    _loadOrder();
                  }
                },
              ),
            ],
            const SizedBox(width: 8),
          ],
        ),
        body: _isLoading
            ? _buildOrderDetailSkeleton()
            : _order == null
            ? Center(
                child: Text(
                  'Order not found',
                  style: GoogleFonts.inter(color: AppColors.textMuted),
                ),
              )
            : RefreshIndicator(
                color: AppColors.primaryDark,
                onRefresh: _loadOrder,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusCard(),
                      const SizedBox(height: 20),
                      _buildCustomerCard(),
                      const SizedBox(height: 20),
                      _buildOrderInfoCard(),
                      const SizedBox(height: 20),
                      _buildItemsCard(),
                      const SizedBox(height: 24),
                      _buildQuickActions(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
        bottomNavigationBar: _isLoading || _order == null
            ? null
            : Container(
                color: AppColors.background,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: _buildFinancialCard(),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final status = (_order!['status'] ?? '').toString();
    final color = _statusColorFor(status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(LucideIcons.package, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Status',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          if (!OrderConstants.terminalStates.contains(status.toLowerCase()))
            IconButton.filled(
              onPressed: _isUpdating ? null : () => _showStatusPicker(),
              icon: _isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(LucideIcons.chevronDown, size: 20),
              style: IconButton.styleFrom(backgroundColor: color),
            ),
        ],
      ),
    );
  }

  void _showStatusPicker() {
    final status = (_order!['status'] ?? '').toString().toLowerCase();
    final allowed = OrderConstants.allowedTransitions[status] ?? [];

    if (allowed.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Update Status',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 24),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allowed.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final s = allowed[index];
                final color = _statusColorFor(s);
                return InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    _updateStatus(s);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          s.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                        const Spacer(),
                        Icon(LucideIcons.chevronRight, size: 18, color: color),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }


  String _customerNotesText() {
    final candidates = [
      _order!['shippingNotes'],
      _order!['customerNotes'],
      _order!['orderNotes'],
      _order!['customerNote'],
      _order!['orderNote'],
    ];

    for (final candidate in candidates) {
      String text = '';
      if (candidate is List) {
        text = candidate
            .map(
              (e) => e is Map ? e['content']?.toString() ?? '' : e.toString(),
            )
            .where((e) => e.trim().isNotEmpty)
            .join(' - ');
      } else if (candidate is Map) {
        text =
            (candidate['content'] ??
                    candidate['text'] ??
                    candidate['note'] ??
                    '')
                .toString();
      } else if (candidate != null) {
        text = candidate.toString();
      }

      text = text.trim();
      if (text.isEmpty) continue;

      // Manual orders are stored as "[SOURCE] note"; hide the source-only marker
      // and show only the actual customer/admin-entered order note.
      text = text.replaceFirst(RegExp(r'^\\[[^\\]]+\\]\\s*'), '').trim();
      if (text.isNotEmpty) return text;
    }

    return '';
  }

  Widget _buildCustomerCard() {
    final notesText = _customerNotesText();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.user,
                size: 18,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: 8),
              Text(
                'Customer Info',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _infoRow(
            LucideIcons.user,
            'Name',
            (_order!['displayName']?.toString().isNotEmpty == true)
                ? _order!['displayName']
                : (_order!['customer']?['name']?.toString().isNotEmpty == true)
                ? _order!['customer']['name']
                : 'Guest',
          ),
          _infoRow(
            LucideIcons.phone,
            'Phone',
            (_order!['phone']?.toString().isNotEmpty == true)
                ? _order!['phone']
                : (_order!['shippingPhone']?.toString().isNotEmpty == true)
                ? _order!['shippingPhone']
                : (_order!['customerPhone']?.toString().isNotEmpty == true)
                ? _order!['customerPhone']
                : (_order!['phoneNumber']?.toString().isNotEmpty == true)
                ? _order!['phoneNumber']
                : (_order!['customer']?['phone']?.toString().isNotEmpty == true)
                ? _order!['customer']['phone']
                : '-',
          ),
          if ((_order!['alternativePhone'] ??
                      _order!['customer']?['alternativePhone']) !=
                  null &&
              (_order!['alternativePhone'] ??
                      _order!['customer']?['alternativePhone'])
                  .toString()
                  .trim()
                  .isNotEmpty)
            _infoRow(
              LucideIcons.phoneCall,
              'Alt. Phone',
              _order!['alternativePhone'] ??
                  _order!['customer']['alternativePhone'],
            ),
          if ((_order!['email'] ?? _order!['customer']?['email']) != null &&
              (_order!['email'] ?? _order!['customer']?['email'])
                  .toString()
                  .trim()
                  .isNotEmpty)
            _infoRow(
              LucideIcons.mail,
              'Email',
              _order!['email'] ?? _order!['customer']['email'],
            ),
          _infoRow(
            LucideIcons.mapPin,
            'Address',
            [
                      _order!['shippingAddress'],
                      _order!['shippingCity'],
                      _order!['shippingGovernorate'],
                    ]
                    .where((e) => e != null && e.toString().trim().isNotEmpty)
                    .join(', ')
                    .isEmpty
                ? '-'
                : [
                        _order!['shippingAddress'],
                        _order!['shippingCity'],
                        _order!['shippingGovernorate'],
                      ]
                      .where((e) => e != null && e.toString().trim().isNotEmpty)
                      .join(', '),
          ),
          _infoRow(
            LucideIcons.fileText,
            'Customer Notes',
            notesText.isNotEmpty ? notesText : '-',
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard() {
    final source = (_order!['source'] ?? 'website').toString().toUpperCase();
    final payment = (_order!['paymentMethod'] ?? 'cod')
        .toString()
        .toUpperCase();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.info,
                size: 18,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: 8),
              Text(
                'Additional Info',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _infoRow(LucideIcons.globe, 'Order Source', source),
          _infoRow(LucideIcons.creditCard, 'Payment Method', payment),
          _infoRow(
            LucideIcons.calendar,
            'Order Date',
            _formatDate(_order!['createdAt']),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
    final items = (_order!['items'] as List? ?? []);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.shoppingBag,
                    size: 18,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Order Items',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
              Text(
                '${items.length} items',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 50,
                      height: 50,
                      color: AppColors.background,
                      child:
                          (item['imageUrl'] ?? item['product']?['imageUrl']) !=
                              null
                          ? CachedNetworkImage(
                              cacheManager: AppImageCacheManager.instance,
                              imageUrl:
                                  item['imageUrl'] ??
                                  item['product']['imageUrl'],
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Container(color: AppColors.shimmer),
                              errorWidget: (context, url, error) => const Icon(
                                LucideIcons.image,
                                color: AppColors.textMuted,
                                size: 20,
                              ),
                            )
                          : const Icon(
                              LucideIcons.image,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] ?? 'Product',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Quantity: ${item['quantity']}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${item['price']} EGP',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialCard() {
    final double total = (_order!['totalPrice'] as num?)?.toDouble() ?? 0.0;
    final double shipping =
        (_order!['shippingCost'] as num?)?.toDouble() ?? 0.0;
    final double discount =
        (_order!['discountAmount'] as num?)?.toDouble() ?? 0.0;
    final double subtotal = total - shipping + discount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _financeRow(
            'Subtotal',
            '${subtotal.toStringAsFixed(0)} EGP',
            Colors.white70,
          ),
          const SizedBox(height: 12),
          _financeRow(
            'Shipping',
            '${shipping.toStringAsFixed(0)} EGP',
            Colors.white70,
          ),
          if (discount > 0) ...[
            const SizedBox(height: 12),
            _financeRow(
              'Discount',
              '-${discount.toStringAsFixed(0)} EGP',
              Colors.greenAccent,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Colors.white10, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                '${total.toStringAsFixed(0)} EGP',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetailSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status card skeleton
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                const AppShimmer(width: 52, height: 52, borderRadius: 16),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      AppShimmer(width: 90, height: 12),
                      SizedBox(height: 8),
                      AppShimmer(width: 140, height: 22),
                    ],
                  ),
                ),
                const AppShimmer(width: 40, height: 40, borderRadius: 12),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Customer card skeleton
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    AppShimmer(width: 18, height: 18, borderRadius: 4),
                    SizedBox(width: 8),
                    AppShimmer(width: 110, height: 14),
                  ],
                ),
                const SizedBox(height: 20),
                for (int i = 0; i < 4; i++) ...[
                  Row(
                    children: [
                      const AppShimmer(width: 14, height: 14, borderRadius: 4),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppShimmer(width: 60, height: 10),
                            const SizedBox(height: 4),
                            AppShimmer(
                              width: i == 3 ? 200.0 : 140.0,
                              height: 14,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Order info card skeleton
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    AppShimmer(width: 18, height: 18, borderRadius: 4),
                    SizedBox(width: 8),
                    AppShimmer(width: 120, height: 14),
                  ],
                ),
                const SizedBox(height: 20),
                for (int i = 0; i < 2; i++) ...[
                  Row(
                    children: const [
                      AppShimmer(width: 14, height: 14, borderRadius: 4),
                      SizedBox(width: 12),
                      AppShimmer(width: 100, height: 14),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Items card skeleton
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        AppShimmer(width: 18, height: 18, borderRadius: 4),
                        SizedBox(width: 8),
                        AppShimmer(width: 90, height: 14),
                      ],
                    ),
                    const AppShimmer(width: 50, height: 12),
                  ],
                ),
                const SizedBox(height: 20),
                for (int i = 0; i < 3; i++) ...[
                  Row(
                    children: [
                      const AppShimmer(width: 50, height: 50, borderRadius: 12),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            AppShimmer(width: 120, height: 14),
                            SizedBox(height: 4),
                            AppShimmer(width: 70, height: 11),
                          ],
                        ),
                      ),
                      const AppShimmer(width: 60, height: 14),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Quick actions skeleton
          Row(
            children: [
              for (int i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      children: const [
                        AppShimmer(width: 24, height: 24, borderRadius: 6),
                        SizedBox(height: 8),
                        AppShimmer(width: 50, height: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {VoidCallback? onTap}) {
    Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 8),
          const Icon(LucideIcons.calendar, size: 16, color: AppColors.primaryDark),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: content,
              ),
            )
          : content,
    );
  }

  Widget _financeRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: color)),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionBtn(
            icon: LucideIcons.messageCircle,
            label: 'WhatsApp',
            color: const Color(0xFF128C7E),
            onTap: _shareViaWhatsApp,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionBtn(
            icon: LucideIcons.printer,
            label: 'Print',
            color: const Color(0xFF475569),
            onTap: _showPrintOptions,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionBtn(
            icon: LucideIcons.messageSquare,
            label: 'Notes',
            color: const Color(0xFFD97706),
            onTap: _showNotesBottomSheet,
          ),
        ),
      ],
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotesBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final notes = (_order!['notes'] as List<dynamic>?) ?? [];
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.messageSquare,
                        size: 20,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Admin Notes',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (notes.isNotEmpty) ...[
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: notes.length,
                        itemBuilder: (context, index) {
                          final n = notes[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          n['content'] ?? '',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () async {
                                          HapticFeedback.lightImpact();
                                          setModalState(
                                            () => _isAddingNote = true,
                                          );
                                          try {
                                            final token = context
                                                .read<AuthProvider>()
                                                .token;
                                            final client = ApiClient(
                                              token: token,
                                            );
                                            await client.patch(
                                              '/api/admin/auth/orders/${widget.orderId}',
                                              body: {
                                                'action': 'delete_note',
                                                'noteId': n['id'],
                                              },
                                            );
                                            await _loadOrder();
                                            if (context.mounted) {
                                              setModalState(() {});
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showAppToast(
                                                AppToast.snackBar(
                                                  content: Text('Failed: $e'),
                                                  backgroundColor:
                                                      AppColors.error,
                                                ),
                                              );
                                            }
                                          } finally {
                                            if (mounted) {
                                              setModalState(
                                                () => _isAddingNote = false,
                                              );
                                            }
                                          }
                                        },
                                        child: const Icon(
                                          LucideIcons.trash2,
                                          size: 16,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatDate(n['createdAt']),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No notes added yet.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _noteController,
                          style: GoogleFonts.inter(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Add an internal note...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textMuted,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        onPressed: _isAddingNote
                            ? null
                            : () async {
                                final text = _noteController.text.trim();
                                if (text.isEmpty) return;

                                HapticFeedback.lightImpact();
                                FocusScope.of(context).unfocus();
                                setModalState(() => _isAddingNote = true);
                                try {
                                  final token = context
                                      .read<AuthProvider>()
                                      .token;
                                  final client = ApiClient(token: token);
                                  await client.patch(
                                    '/api/admin/auth/orders/${widget.orderId}',
                                    body: {'note': text},
                                  );
                                  _noteController.clear();
                                  await _loadOrder();
                                  if (mounted) setModalState(() {});
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showAppToast(
                                      AppToast.snackBar(
                                        content: Text('Failed: $e'),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setModalState(() => _isAddingNote = false);
                                  }
                                }
                              },
                        icon: _isAddingNote
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(LucideIcons.send, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          padding: const EdgeInsets.all(14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getWhatsAppMessageText() {
    final status = _order!['status']?.toString().toLowerCase() ?? 'pending';

    final name =
        _order!['displayName'] ?? _order!['customer']?['name'] ?? 'Customer';
    final orderNo = _order!['orderNumber']?.toString() ?? '';
    final total = (_order!['totalPrice'] as num?)?.toDouble() ?? 0.0;
    final shipping = (_order!['shippingCost'] as num?)?.toDouble() ?? 0.0;

    if (status == 'delivered' || status == 'cash_received') {
      return '''مرحبًا $name ✨
نتمنى إن طلبك من LegaCy وصلك بأمان وبالشكل اللي كنت متوقعه.
يسعدنا جدًا نسمع رأيك.
ولو عندك أي ملاحظة أو استفسار، يشرفنا تواصلك معنا.
شكرًا لثقتك بنا 💚''';
    } else if (status == 'shipped' || status == 'out_for_delivery') {
      return '''مرحبًا $name ✨
طلبك رقم #$orderNo من LegaCy خرج للشحن وفي طريقه ليك! 🚚
قيمة الطلب: $total EGP
المندوب هيتواصل معاك قريب جداً للتسليم.
لو عندك أي استفسار، إحنا دايماً معاك 💚''';
    } else if (status == 'preparing') {
      return '''مرحبًا $name ✨
طلبك رقم #$orderNo من LegaCy قيد التجهيز حالياً! ⏳
بنجاهزه بكل حب واهتمام عشان يوصلك في أحسن صورة.
هنبلغك أول ما يخرج للشحن.
شكرًا لثقتك بنا 💚''';
    } else if (status == 'cancelled' || status == 'payment_failed') {
      return '''مرحبًا $name ✨
تم إلغاء طلبك رقم #$orderNo من LegaCy.
نتمنى نشوفك تاني قريب وتكون جزء من عيلتنا 💚
لو حابب تستفسر عن أي حاجة، إحنا موجودين دايماً!''';
    } else if (status == 'refunded') {
      return '''مرحبًا $name ✨
تم استرجاع طلبك رقم #$orderNo بنجاح، وتمت عملية الـ Refund للرصيد المستحق.
نتمنى نشوفك تاني قريب وتكون جزء من عيلة LegaCy 💚
لو حابب تستفسر عن أي حاجة، إحنا موجودين دايماً!''';
    } else {
      // Pending / Confirmed / Processing
      final items = (_order!['items'] as List? ?? []);
      String itemsText = '';
      for (int i = 0; i < items.length; i++) {
        String itemName = items[i]['name']?.toString() ?? '';
        itemName = itemName.replaceAll(RegExp(r'\s*\([^)]*\)$'), '').trim();
        if (i == 0) {
          itemsText += '⌚ Watch : $itemName';
        } else {
          itemsText += '\n                     $itemName';
        }
      }

      String shippingText = shipping <= 0
          ? 'Free Shipping'
          : '$shipping EGP Shipping';

      final shippingAddrObj = _order!['shippingAddress'] is Map
          ? _order!['shippingAddress']
          : null;
      final shippingAddrStr = _order!['shippingAddress'] is String
          ? _order!['shippingAddress']
          : '';
      final address = shippingAddrStr.isNotEmpty
          ? shippingAddrStr
          : (shippingAddrObj?['address'] ?? _order!['address'] ?? '');
      final gov =
          shippingAddrObj?['governorate'] ??
          shippingAddrObj?['state'] ??
          _order!['shippingGovernorate'] ??
          _order!['governorate'] ??
          _order!['customer']?['governorate'] ??
          '';
      final city =
          shippingAddrObj?['city'] ??
          _order!['shippingCity'] ??
          _order!['city'] ??
          _order!['customer']?['city'] ??
          '';

      final List<String> addressParts = [];
      if (gov.toString().isNotEmpty) addressParts.add(gov.toString());
      if (city.toString().isNotEmpty) addressParts.add(city.toString());
      if (address.toString().isNotEmpty) addressParts.add(address.toString());
      final fullAddress = addressParts.join(' ، ');

      final phone1 =
          _order!['phone'] ??
          _order!['shippingPhone'] ??
          _order!['customerPhone'] ??
          _order!['phoneNumber'] ??
          _order!['customer']?['phone'] ??
          '';
      final phone2 =
          _order!['alternativePhone'] ??
          _order!['altPhone'] ??
          _order!['customer']?['alternativePhone'] ??
          '';

      return '''Thank you for choosing LegaCy 💚

Order : #$orderNo
Name : $name
$itemsText
💰 Total Due : EGP $total + $shippingText
📍 Address : $fullAddress
Delivered in (1 : 4) Days
Phone 1 : $phone1${phone2.toString().trim().isNotEmpty ? '\nPhone 2 : $phone2' : ''}

Thanks for shopping with us! 💚''';
    }
  }

  void _shareViaWhatsApp() async {
    final phone =
        _order!['phone'] ??
        _order!['shippingPhone'] ??
        _order!['customerPhone'] ??
        _order!['phoneNumber'] ??
        _order!['customer']?['phone'] ??
        '';
    final text = _getWhatsAppMessageText();

    String formattedPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '2$formattedPhone'; // Egypt country code fallback
    }

    final url =
        "https://wa.me/$formattedPhone?text=${Uri.encodeComponent(text)}";

    if (Platform.isAndroid) {
      try {
        final intent = AndroidIntent(
          action: 'action_view',
          data: url,
          package: 'com.whatsapp.w4b', // Force WhatsApp Business
        );
        await intent.launch();
      } catch (e) {
        // Fallback to url_launcher if WhatsApp Business is not installed
        _launchWhatsAppFallback(url);
      }
    } else {
      _launchWhatsAppFallback(url);
    }
  }

  Future<void> _launchWhatsAppFallback(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bool launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
      } catch (e2) {
        messenger.showAppToast(
          AppToast.snackBar(
            content: Text('WhatsApp is not installed or supported.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showPrintOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Invoice Options',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              _buildOptionTile(
                icon: LucideIcons.fileText,
                title: 'Export as PDF',
                subtitle: 'Save or share as a PDF document',
                onTap: () {
                  Navigator.pop(context);
                  _processInvoice(action: 'pdf');
                },
              ),
              const SizedBox(height: 16),
              _buildOptionTile(
                icon: LucideIcons.share,
                title: 'Share Image',
                subtitle: 'Share invoice via WhatsApp or others',
                onTap: () {
                  Navigator.pop(context);
                  _processInvoice(action: 'share_image');
                },
              ),
              const SizedBox(height: 16),
              _buildOptionTile(
                icon: LucideIcons.download,
                title: 'Save Image',
                subtitle: 'Save invoice directly to phone gallery',
                onTap: () {
                  Navigator.pop(context);
                  _processInvoice(action: 'save_image');
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processInvoice({required String action}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pdfDoc = await _generateInvoicePdf();
      final bytes = await pdfDoc.save();
      final orderNo = _order!['orderNumber']?.toString() ?? 'unknown';

      if (action == 'share_image' || action == 'save_image') {
        final raster = await Printing.raster(bytes, pages: [0], dpi: 300).first;
        final rawPngBytes = await raster.toPng();
        final pngBytes = await _fillImageBackgroundWithWhite(rawPngBytes);
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/Invoice_$orderNo.png');
        await file.writeAsBytes(pngBytes);

        if (action == 'save_image') {
          // Check permissions
          bool hasAccess = await Gal.hasAccess(toAlbum: true);
          if (!hasAccess) {
            hasAccess = await Gal.requestAccess(toAlbum: true);
          }
          if (hasAccess) {
            await Gal.putImage(file.path, album: 'LegaCy');
            messenger.showAppToast(
              AppToast.snackBar(
                content: Text('Image saved to gallery successfully!'),
                backgroundColor: AppColors.success,
              ),
            );
          } else {
            messenger.showAppToast(
              AppToast.snackBar(
                content: Text('Storage permission denied.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        } else {
          // Share image
          // ignore: deprecated_member_use
          await Share.shareXFiles([
            XFile(file.path),
          ], text: 'Invoice #$orderNo');
        }
      } else {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
          name: 'Invoice_$orderNo',
        );
      }
    } catch (e) {
      messenger.showAppToast(
        AppToast.snackBar(
          content: Text('Failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<pw.Document> _generateInvoicePdf() async {
    final pdfDoc = pw.Document();

    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    const primaryColor = PdfColor.fromInt(0xFF12403C);
    const accentColor = PdfColor.fromInt(0xFFD4AF37);
    const bgColor = PdfColor.fromInt(0xFFFCF8F3);

    String reshape(String text) => ArabicReshaper.instance.reshape(text);

    String safeString(dynamic val) {
      if (val == null) return '';
      if (val is List) {
        return val
            .map((e) {
              if (e is Map) return e['content']?.toString() ?? '';
              return e.toString();
            })
            .where((e) => e.toString().trim().isNotEmpty)
            .join(' - ');
      }
      if (val is Map) return val['content']?.toString() ?? '';
      return val.toString();
    }

    final name = reshape(
      safeString(
        _order!['displayName'] ?? _order!['customer']?['name'] ?? 'Customer',
      ),
    );
    final phone = safeString(
      _order!['phone'] ??
          _order!['shippingPhone'] ??
          _order!['customerPhone'] ??
          _order!['phoneNumber'] ??
          _order!['customer']?['phone'],
    );

    final shippingAddrObj = _order!['shippingAddress'] is Map
        ? _order!['shippingAddress']
        : null;
    final shippingAddrStr = _order!['shippingAddress'] is String
        ? _order!['shippingAddress']
        : '';
    final rawAddress = safeString(
      shippingAddrStr.isNotEmpty
          ? shippingAddrStr
          : (shippingAddrObj?['address'] ?? _order!['address']),
    );

    final rawGov = safeString(
      shippingAddrObj?['governorate'] ??
          shippingAddrObj?['state'] ??
          _order!['shippingGovernorate'] ??
          _order!['governorate'] ??
          _order!['customer']?['governorate'],
    );
    final rawCity = safeString(
      shippingAddrObj?['city'] ??
          _order!['shippingCity'] ??
          _order!['city'] ??
          _order!['customer']?['city'],
    );

    final List<String> addressParts = [];
    if (rawGov.isNotEmpty) addressParts.add(rawGov);
    if (rawCity.isNotEmpty) addressParts.add(rawCity);
    if (rawAddress.isNotEmpty) addressParts.add(rawAddress);
    final fullAddress = reshape(addressParts.join(' - '));

    final altPhone = safeString(
      _order!['alternativePhone'] ??
          _order!['altPhone'] ??
          _order!['customer']?['alternativePhone'],
    );

    final orderNo = _order!['orderNumber']?.toString() ?? 'N/A';
    final items = (_order!['items'] as List? ?? []);

    final Map<int, pw.ImageProvider> itemImages = {};
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final imageUrl = item['product']?['imageUrl'] ?? item['imageUrl'];
      if (imageUrl != null && imageUrl.toString().startsWith('http')) {
        try {
          final imageFile = await AppImageCacheManager.instance.getSingleFile(
            imageUrl.toString(),
          );
          itemImages[i] = pw.MemoryImage(await imageFile.readAsBytes());
        } catch (_) {}
      }
    }

    final subtotal = (_order!['subtotal'] as num?)?.toDouble() ?? 0.0;
    final shipping = (_order!['shippingCost'] as num?)?.toDouble() ?? 0.0;
    final total = (_order!['totalPrice'] as num?)?.toDouble() ?? 0.0;

    double discount = (_order!['discount'] as num?)?.toDouble() ?? 0.0;
    if (discount <= 0) {
      double diff = (subtotal + shipping) - total;
      if (diff > 0.5) discount = diff;
    }

    final paymentMethod = _order!['paymentMethod'] ?? 'COD';
    final orderDate = _formatDate(_order!['createdAt']);

    pw.Widget buildInfoRow(
      String label,
      String value, {
      bool isRtl = false,
      bool isBold = false,
    }) {
      if (value.toString().trim().isEmpty) return pw.SizedBox();
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 80,
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 12,
                  color: primaryColor,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                value.toString(),
                textAlign: pw.TextAlign.left,
                textDirection: isRtl
                    ? pw.TextDirection.rtl
                    : pw.TextDirection.ltr,
                style: pw.TextStyle(
                  fontSize: 12,
                  color: isBold ? primaryColor : PdfColors.grey800,
                  fontWeight: isBold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );
    }

    pdfDoc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 48),
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font, bold: boldFont),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: bgColor),
          ),
        ),
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(24),
              decoration: const pw.BoxDecoration(
                color: primaryColor,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'LegaCy',
                        style: pw.TextStyle(
                          color: accentColor,
                          fontSize: 32,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Premium Watches',
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        '#$orderNo',
                        style: pw.TextStyle(color: accentColor, fontSize: 18),
                      ),
                      pw.Text(
                        'Date: $orderDate',
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 32),

            // Customer Info & Payment Method
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'BILLED TO:',
                  style: pw.TextStyle(
                    color: primaryColor,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: buildInfoRow(
                        'Name:',
                        name,
                        isRtl: true,
                        isBold: true,
                      ),
                    ),
                    pw.Expanded(
                      child: buildInfoRow(
                        'Payment:',
                        paymentMethod.toString().toUpperCase(),
                        isBold: true,
                      ),
                    ),
                  ],
                ),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(child: buildInfoRow('Phone:', phone)),
                    pw.Expanded(
                      child: buildInfoRow('Alt Phone:', altPhone.toString()),
                    ),
                  ],
                ),
                buildInfoRow('Address:', fullAddress, isRtl: true),
              ],
            ),
            pw.SizedBox(height: 32),

            // Table Header
            pw.Container(
              decoration: pw.BoxDecoration(
                color: bgColor,
                border: const pw.Border(
                  bottom: pw.BorderSide(color: primaryColor, width: 2),
                ),
              ),
              padding: const pw.EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 8,
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                      'ITEM',
                      style: pw.TextStyle(
                        color: primaryColor,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'QTY',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: primaryColor,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'PRICE',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        color: primaryColor,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'TOTAL',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        color: primaryColor,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Table Items
            ...items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final qty = item['quantity'] ?? 1;
              final price = (item['price'] as num?)?.toDouble() ?? 0.0;
              final itemTotal = price * qty;

              String cleanItemName = item['name']?.toString() ?? '';
              cleanItemName = cleanItemName
                  .replaceAll(RegExp(r'\s*\([^)]*\)$'), '')
                  .trim();
              final itemName = reshape(cleanItemName);
              return pw.Container(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                  ),
                ),
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Expanded(
                      flex: 4,
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          if (itemImages[i] != null) ...[
                            pw.Container(
                              width: 24,
                              height: 24,
                              decoration: pw.BoxDecoration(
                                borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(4),
                                ),
                                image: pw.DecorationImage(
                                  image: itemImages[i]!,
                                  fit: pw.BoxFit.cover,
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 8),
                          ],
                          pw.Expanded(
                            child: pw.Text(
                              itemName,
                              textDirection: pw.TextDirection.rtl,
                              style: const pw.TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        qty.toString(),
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        '${price.toStringAsFixed(2)} EGP',
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        '${itemTotal.toStringAsFixed(2)} EGP',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            pw.SizedBox(height: 24),

            // Summary
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 250,
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Subtotal',
                            style: const pw.TextStyle(fontSize: 14),
                          ),
                          pw.Text(
                            '${subtotal.toStringAsFixed(2)} EGP',
                            style: const pw.TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Shipping',
                            style: const pw.TextStyle(fontSize: 14),
                          ),
                          pw.Text(
                            '${shipping.toStringAsFixed(2)} EGP',
                            style: const pw.TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      if (discount > 0) ...[
                        pw.SizedBox(height: 8),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Discount',
                              style: pw.TextStyle(
                                fontSize: 14,
                                color: primaryColor,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              '-${discount.toStringAsFixed(2)} EGP',
                              style: pw.TextStyle(
                                fontSize: 14,
                                color: primaryColor,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                      pw.SizedBox(height: 12),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: const pw.BoxDecoration(
                          color: primaryColor,
                          borderRadius: pw.BorderRadius.all(
                            pw.Radius.circular(8),
                          ),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Total',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              '${total.toStringAsFixed(2)} EGP',
                              style: pw.TextStyle(
                                color: accentColor,
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
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

            pw.SizedBox(height: 48),

            // Footer
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'Thank you for shopping with LegaCy!',
                    style: pw.TextStyle(
                      color: primaryColor,
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Please note that a 14-day exchange and return policy applies to all orders in case of any issues.',
                    style: const pw.TextStyle(
                      color: PdfColors.grey600,
                      fontSize: 10,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'For inquiries, please contact us on WhatsApp.',
                    style: const pw.TextStyle(
                      color: PdfColors.grey600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );
    return pdfDoc;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<Uint8List> _fillImageBackgroundWithWhite(Uint8List pngBytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(pngBytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image image = frameInfo.image;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    final ui.Paint paint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);

    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      paint,
    );

    canvas.drawImage(image, ui.Offset.zero, ui.Paint());

    final ui.Picture picture = recorder.endRecording();
    final ui.Image whiteBgImage = await picture.toImage(image.width, image.height);
    final ByteData? byteData = await whiteBgImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
