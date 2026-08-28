import 'package:admin_app/core/widgets/app_toast.dart';
import 'package:admin_app/core/widgets/app_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'add_coupon_screen.dart';

class ShippingPromosScreen extends StatefulWidget {
  const ShippingPromosScreen({super.key});
  @override
  State<ShippingPromosScreen> createState() => _ShippingPromosScreenState();
}

class _ShippingPromosScreenState extends State<ShippingPromosScreen> {
  bool _isLoading = true;
  bool _isFreeShippingEnabled = false;
  final TextEditingController _thresholdController = TextEditingController();
  bool _showProgressBar = true;
  bool _savingSettings = false;

  bool _originalFreeShippingEnabled = false;
  String _originalThreshold = '2000';
  bool _originalShowProgressBar = true;

  bool get _hasChanges {
    return _isFreeShippingEnabled != _originalFreeShippingEnabled ||
           _thresholdController.text != _originalThreshold ||
           _showProgressBar != _originalShowProgressBar;
  }

  // Shipping coupons
  List<dynamic> _shippingCoupons = [];
  bool _couponsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadSettings(), _loadShippingCoupons()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadSettings() async {
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final data = await client.get('/api/admin/config/settings?keys=FREE_SHIPPING_ENABLED,FREE_SHIPPING_THRESHOLD,FREE_SHIPPING_SHOW_BAR');
      if (mounted) {
        setState(() {
          _isFreeShippingEnabled = data['FREE_SHIPPING_ENABLED'] == 'true';
          _thresholdController.text = data['FREE_SHIPPING_THRESHOLD'] ?? '2000';
          _showProgressBar = data['FREE_SHIPPING_SHOW_BAR'] != 'false';
          
          _originalFreeShippingEnabled = _isFreeShippingEnabled;
          _originalThreshold = _thresholdController.text;
          _originalShowProgressBar = _showProgressBar;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadShippingCoupons() async {
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final data = await client.get('/api/admin/auth/coupons');
      if (mounted) {
        final all = data['coupons'] as List<dynamic>;
        setState(() {
          _shippingCoupons = all.where((c) {
            final type = (c['discountType'] ?? '').toString().toUpperCase();
            return type == 'FREE_SHIPPING' || type == 'SHIPPING_PERCENTAGE' || type == 'SHIPPING_FIXED';
          }).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    setState(() => _savingSettings = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      await client.put('/api/admin/config/settings', body: {
        'settings': [
          {'key': 'FREE_SHIPPING_ENABLED', 'value': _isFreeShippingEnabled.toString()},
          {'key': 'FREE_SHIPPING_THRESHOLD', 'value': _thresholdController.text},
          {'key': 'FREE_SHIPPING_SHOW_BAR', 'value': _showProgressBar.toString()},
        ]
      });
      if (mounted) {
        setState(() {
          _originalFreeShippingEnabled = _isFreeShippingEnabled;
          _originalThreshold = _thresholdController.text;
          _originalShowProgressBar = _showProgressBar;
        });
        ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(content: Text('Settings saved successfully'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(content: Text('Error: $e'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  Future<void> _toggleCouponStatus(String id, bool currentStatus) async {
    HapticFeedback.lightImpact();
    setState(() => _couponsLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      await client.put('/api/admin/auth/coupons/$id', body: {'isActive': !currentStatus});
      await _loadShippingCoupons();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(content: Text('Error: $e'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _couponsLoading = false);
    }
  }

  Future<void> _deleteCoupon(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Delete Coupon?', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
        content: Text('This will permanently delete the shipping coupon.', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textMuted, fontWeight: FontWeight.w600))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    HapticFeedback.mediumImpact();
    setState(() => _couponsLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      await client.delete('/api/admin/auth/coupons/$id');
      if (mounted) {
        ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(content: Text('Coupon deleted'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
      }
      await _loadShippingCoupons();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(content: Text('Error: $e'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _couponsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF0EA5E9);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(LucideIcons.truck, color: color),
            const SizedBox(width: 8),
            Text('Shipping Options', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
          ],
        ),
        backgroundColor: AppColors.surface, surfaceTintColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.arrowLeft, color: AppColors.primaryDark), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 3,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppShimmer(width: 120, height: 18),
                          AppShimmer(width: 44, height: 24, borderRadius: 12),
                        ],
                      ),
                      SizedBox(height: 8),
                      AppShimmer(width: 220, height: 14),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          AppShimmer(width: 80, height: 28, borderRadius: 8),
                          SizedBox(width: 8),
                          AppShimmer(width: 80, height: 28, borderRadius: 8),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              color: color,
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ─── SECTION 1: Free Shipping Settings ───
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Free Shipping Promotion', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                  const SizedBox(height: 4),
                                  Text('Show progress bar at checkout to encourage higher cart value', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isFreeShippingEnabled,
                              onChanged: (v) => setState(() => _isFreeShippingEnabled = v),
                              activeTrackColor: color,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Divider(color: AppColors.divider, height: 1),
                        const SizedBox(height: 20),
                        Text('Free Shipping Threshold (EGP)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text('Orders above this amount get free shipping', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _thresholdController,
                          enabled: _isFreeShippingEnabled,
                          onChanged: (_) => setState(() {}),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(LucideIcons.banknote, color: AppColors.textMuted, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.cardBorder)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: color, width: 2)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Show Progress Bar', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text('Display shipping progress bar in cart & checkout', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                            Switch(
                              value: _showProgressBar,
                              onChanged: _isFreeShippingEnabled ? (v) => setState(() => _showProgressBar = v) : null,
                              activeTrackColor: color,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_hasChanges && !_savingSettings) ? _saveSettings : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              elevation: 0,
                              disabledBackgroundColor: Colors.grey.shade300,
                              disabledForegroundColor: Colors.grey.shade500,
                            ),
                            child: _savingSettings
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text('Save Settings', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── SECTION 2: Shipping Promo Codes ───
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('🎫 Shipping Promo Codes', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                      ElevatedButton.icon(
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AddCouponScreen(defaultType: 'FREE_SHIPPING')),
                          );
                          if (result == true) _loadShippingCoupons();
                        },
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: Text('New Code', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_couponsLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: color)))
                  else if (_shippingCoupons.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                            child: Icon(LucideIcons.ticket, size: 32, color: color),
                          ),
                          const SizedBox(height: 16),
                          Text('No Shipping Coupons', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text('Create a shipping promo code', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                        ],
                      ),
                    )
                  else
                    ...List.generate(_shippingCoupons.length, (i) => _buildShippingCouponCard(_shippingCoupons[i])),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildShippingCouponCard(Map<String, dynamic> coupon) {
    final bool isActive = coupon['isActive'] == true;
    final int usageCount = coupon['_count']?['orders'] ?? coupon['currentUsage'] ?? 0;
    final int? limit = coupon['usageLimit'];
    final num val = num.tryParse(coupon['discountValue']?.toString() ?? '0') ?? 0;
    final String type = (coupon['discountType'] ?? '').toString().toUpperCase();

    String typeLabel;
    String valueStr;
    if (type == 'FREE_SHIPPING') {
      typeLabel = 'Free Shipping';
      valueStr = 'FREE';
    } else if (type == 'SHIPPING_PERCENTAGE') {
      typeLabel = 'Percentage';
      valueStr = '$val%';
    } else {
      typeLabel = 'Fixed Amount';
      valueStr = '$val EGP';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? const Color(0xFF0EA5E9).withValues(alpha: 0.4) : AppColors.cardBorder),
        boxShadow: [
          BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Discount Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF0EA5E9).withValues(alpha: 0.1) : AppColors.textMuted.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isActive ? const Color(0xFF0EA5E9).withValues(alpha: 0.3) : Colors.transparent),
                  ),
                  child: Column(
                    children: [
                      Text(valueStr, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: isActive ? const Color(0xFF0EA5E9) : AppColors.textMuted)),
                      Text('OFF', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: isActive ? AppColors.primaryDark : AppColors.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Code & Type
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(coupon['code'] ?? '', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: 1)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.success.withValues(alpha: 0.1) : AppColors.textMuted.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isActive ? 'Active' : 'Inactive',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: isActive ? AppColors.success : AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFF0EA5E9).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text(typeLabel, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF0EA5E9))),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Used: $usageCount ${limit != null ? '/ $limit' : 'times'}',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions
                PopupMenuButton<String>(
                  icon: const Icon(LucideIcons.moreVertical, color: AppColors.textMuted),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (v) {
                    if (v == 'toggle') _toggleCouponStatus(coupon['id'], isActive);
                    if (v == 'edit') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AddCouponScreen(coupon: coupon))).then((r) { if (r == true) _loadShippingCoupons(); });
                    }
                    if (v == 'delete') _deleteCoupon(coupon['id']);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'toggle', child: Row(children: [Icon(isActive ? LucideIcons.pause : LucideIcons.play, size: 16, color: AppColors.textSecondary), const SizedBox(width: 10), Text(isActive ? 'Deactivate' : 'Activate', style: GoogleFonts.inter(fontSize: 13))])),
                    PopupMenuItem(value: 'edit', child: Row(children: [const Icon(LucideIcons.edit2, size: 16, color: AppColors.textSecondary), const SizedBox(width: 10), Text('Edit', style: GoogleFonts.inter(fontSize: 13))])),
                    const PopupMenuDivider(),
                    PopupMenuItem(value: 'delete', child: Row(children: [const Icon(LucideIcons.trash2, size: 16, color: Colors.red), const SizedBox(width: 10), Text('Delete', style: GoogleFonts.inter(fontSize: 13, color: Colors.red))])),
                  ],
                ),
              ],
            ),
          ),

          // Footer details
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              border: Border(top: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.5))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (coupon['minOrderValue'] != null)
                  Row(
                    children: [
                      const Icon(LucideIcons.shoppingCart, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('Min: ${coupon['minOrderValue']} EGP', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                    ],
                  )
                else
                  const SizedBox.shrink(),
                Row(
                  children: [
                    const Icon(LucideIcons.calendar, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      coupon['endDate'] != null
                          ? 'Ends: ${DateTime.parse(coupon['endDate']).toString().substring(0, 10)}'
                          : 'No expiry',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

