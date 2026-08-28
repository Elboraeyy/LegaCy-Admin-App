import 'package:admin_app/core/services/app_image_cache_manager.dart';
import 'package:admin_app/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/products/add_product_screen.dart';
import 'package:admin_app/features/products/add_batch_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _product;
  late TabController _infoTabController;
  bool _isLoading = false;
  List<dynamic> _reviews = [];

  @override
  void initState() {
    super.initState();
    _product = Map<String, dynamic>.from(widget.product);
    _infoTabController = TabController(length: 3, vsync: this);
    _loadReviews();
  }

  Future<void> _refreshProduct() async {
    setState(() => _isLoading = true);
    try {
      final client = ApiClient(token: context.read<AuthProvider>().token);
      final data = await client.get('/api/products/${_product['id']}');
      if (mounted) {
        setState(() {
          _product = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _snack('Failed to refresh: $e');
    }
  }

  Future<void> _loadReviews() async {
    try {
      final client = ApiClient(token: context.read<AuthProvider>().token);
      final data = await client.get('/api/admin/auth/reviews?limit=100');
      final allReviews = data['reviews'] as List<dynamic>;

      // Filter reviews for this product
      // Note: We need to ensure the API returns productId or use productName match as fallback
      if (mounted) {
        setState(() {
          _reviews = allReviews
              .where(
                (r) =>
                    r['productId'] == _product['id'] ||
                    r['productName'] == _product['name'],
              )
              .toList();
        });
      }
    } catch (_) {}
  }

  void _snack(String m, {bool ok = false}) {
    ScaffoldMessenger.of(context).showAppToast(
      AppToast.snackBar(
        content: Text(
          m,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  void dispose() {
    _infoTabController.dispose();
    super.dispose();
  }

  void _navigateToEdit() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddProductScreen(product: _product)),
    );
    if (result == true) {
      // In a real scenario, you'd fetch the updated product.
      // For now, we will just pop to the previous screen to reload.
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _updateProduct(Map<String, dynamic> data) async {
    setState(() => _isLoading = true);
    try {
      final client = ApiClient(token: context.read<AuthProvider>().token);
      await client.put(
        '/api/admin/auth/products/${_product['id']}',
        body: data,
      );
      await _refreshProduct();
      _snack('Product updated successfully', ok: true);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _snack('Update failed: $e');
    }
  }

  Future<void> _showStockDialog() async {
    HapticFeedback.mediumImpact();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddBatchScreen(initialProduct: _product),
      ),
    );
    if (result == true) {
      _refreshProduct();
    }
  }

  void _showDiscountBottomSheet() {
    final currentPrice =
        double.tryParse(_product['price']?.toString() ?? '0') ?? 0.0;
    final currentCompareAt =
        double.tryParse(_product['compareAtPrice']?.toString() ?? '0') ?? 0.0;

    final originalPrice = currentCompareAt > 0
        ? currentCompareAt
        : currentPrice;

    // Determine initial state
    bool hasDiscount = currentCompareAt > 0 && currentCompareAt > currentPrice;
    bool isPercentage = true; // Default toggle state

    // Controllers for inputs
    final percentController = TextEditingController();
    final amountController = TextEditingController();

    if (hasDiscount) {
      final discountAmount = originalPrice - currentPrice;
      final discountPercent = (discountAmount / originalPrice) * 100;
      percentController.text = discountPercent.toStringAsFixed(0);
      amountController.text = discountAmount.toStringAsFixed(0);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          double newPrice = originalPrice;
          double savedAmount = 0.0;

          if (hasDiscount) {
            if (isPercentage) {
              final pct = double.tryParse(percentController.text) ?? 0.0;
              savedAmount = originalPrice * (pct / 100);
            } else {
              savedAmount = double.tryParse(amountController.text) ?? 0.0;
            }
            newPrice = originalPrice - savedAmount;
            if (newPrice < 0) newPrice = 0;
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle indicator
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 20),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.cardBorder,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFF59E0B,
                                ).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.tag,
                                color: Color(0xFFF59E0B),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Discount',
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                Text(
                                  'Special offers & sales',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch(
                          value: hasDiscount,
                          activeColor: AppColors.primaryDark.withValues(
                            alpha: 0.5,
                          ),
                          onChanged: (val) {
                            HapticFeedback.lightImpact();
                            setSheetState(() => hasDiscount = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Live Preview Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryDark.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Original Price',
                                      style: GoogleFonts.inter(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      '${originalPrice.toStringAsFixed(0)} EGP',
                                      style: GoogleFonts.inter(
                                        color: hasDiscount
                                            ? Colors.white70
                                            : Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        decoration: hasDiscount
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                                if (hasDiscount) ...[
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Divider(
                                      color: Colors.white24,
                                      height: 1,
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'New Price',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${newPrice.toStringAsFixed(0)} EGP',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF10B981),
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Customer Saves',
                                        style: GoogleFonts.inter(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        '${savedAmount.toStringAsFixed(0)} EGP',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFF59E0B),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          if (hasDiscount) ...[
                            const SizedBox(height: 24),
                            // Toggle Type (Percentage vs Amount)
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setSheetState(
                                          () => isPercentage = true,
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isPercentage
                                              ? AppColors.primaryDark
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            100,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          'Percentage (%)',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isPercentage
                                                ? Colors.white
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setSheetState(
                                          () => isPercentage = false,
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: !isPercentage
                                              ? AppColors.primaryDark
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            100,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          'Fixed Amount',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: !isPercentage
                                                ? Colors.white
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Input Field
                            Text(
                              isPercentage
                                  ? 'Discount Percentage'
                                  : 'Discount Amount',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: isPercentage
                                  ? percentController
                                  : amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                              onChanged: (_) => setSheetState(() {}),
                              decoration: InputDecoration(
                                prefixIcon: Icon(
                                  isPercentage
                                      ? LucideIcons.percent
                                      : LucideIcons.banknote,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                suffixText: isPercentage ? '%' : 'EGP',
                                suffixStyle: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                                filled: true,
                                fillColor: AppColors.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: AppColors.cardBorder,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: AppColors.cardBorder,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: AppColors.primaryDark,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                              ),
                            ),

                            if (isPercentage) ...[
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                children: [10, 15, 20, 25, 50].map((pct) {
                                  return ActionChip(
                                    label: Text(
                                      '$pct%',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    backgroundColor: AppColors.surface,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(100),
                                      side: BorderSide(
                                        color: AppColors.cardBorder,
                                      ),
                                    ),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      percentController.text = pct.toString();
                                      setSheetState(() {});
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),

                  // Footer Actions
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border(
                        top: BorderSide(color: AppColors.cardBorder),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                              ),
                              side: const BorderSide(
                                color: AppColors.cardBorder,
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              if (hasDiscount && newPrice < originalPrice) {
                                _updateProduct({
                                  'price': newPrice,
                                  'compareAtPrice': originalPrice,
                                });
                              } else {
                                // Remove discount
                                _updateProduct({
                                  'price': originalPrice,
                                  'compareAtPrice': null,
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryDark,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Apply Discount',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showBadgeBottomSheet() {
    final List<String> currentTags = List<String>.from(
      _product['detailTags'] ?? [],
    );
    final tagController = TextEditingController();

    final List<Map<String, dynamic>> suggestions = [
      {'label': 'New', 'color': '#3B82F6', 'icon': LucideIcons.sparkles},
      {'label': 'Hot', 'color': '#EF4444', 'icon': LucideIcons.flame},
      {'label': 'Sale', 'color': '#F59E0B', 'icon': LucideIcons.tag},
      {'label': 'Limited', 'color': '#8B5CF6', 'icon': LucideIcons.clock},
      {'label': 'Best Seller', 'color': '#10B981', 'icon': LucideIcons.award},
    ];

    final List<Map<String, String>> colorOptions = [
      {'name': 'Blue', 'hex': '#3B82F6'},
      {'name': 'Red', 'hex': '#EF4444'},
      {'name': 'Amber', 'hex': '#F59E0B'},
      {'name': 'Green', 'hex': '#10B981'},
      {'name': 'Purple', 'hex': '#8B5CF6'},
      {'name': 'Dark', 'hex': '#1E293B'},
      {'name': 'Pink', 'hex': '#EC4899'},
    ];
    String selectedHex = colorOptions[0]['hex']!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle indicator
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 20),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.cardBorder,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF8B5CF6,
                            ).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.sparkles,
                            color: Color(0xFF8B5CF6),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Product Badges',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              Text(
                                'Make this product stand out',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (currentTags.isNotEmpty) ...[
                            Text(
                              'Active Badges',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: currentTags.map((tag) {
                                final parts = tag.split('|');
                                final label = parts[0];
                                final color = parts.length > 1
                                    ? _parseColor(
                                        parts[1],
                                        AppColors.primaryDark,
                                      )
                                    : AppColors.primaryDark;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.3),
                                    ),
                                    borderRadius: BorderRadius.circular(20),
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
                                      const SizedBox(width: 8),
                                      Text(
                                        label,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: color,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          setSheetState(
                                            () => currentTags.remove(tag),
                                          );
                                        },
                                        child: Icon(
                                          LucideIcons.x,
                                          size: 14,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),
                            const Divider(color: AppColors.cardBorder),
                            const SizedBox(height: 24),
                          ],

                          Text(
                            'Create Custom Badge',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: tagController,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Exclusive',
                                    hintStyle: GoogleFonts.inter(
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    filled: true,
                                    fillColor: AppColors.background,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: AppColors.primaryDark,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          LucideIcons.plus,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                      onPressed: () {
                                        if (tagController.text
                                            .trim()
                                            .isNotEmpty) {
                                          HapticFeedback.mediumImpact();
                                          setSheetState(() {
                                            currentTags.add(
                                              '${tagController.text.trim()}|$selectedHex',
                                            );
                                            tagController.clear();
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Badge Color',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: colorOptions.map((c) {
                                      final isSelected =
                                          selectedHex == c['hex'];
                                      final color = _parseColor(
                                        c['hex']!,
                                        Colors.grey,
                                      );
                                      return GestureDetector(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setSheetState(
                                            () => selectedHex = c['hex']!,
                                          );
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          margin: const EdgeInsets.only(
                                            right: 12,
                                          ),
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.transparent,
                                              width: 3,
                                            ),
                                            boxShadow: [
                                              if (isSelected)
                                                BoxShadow(
                                                  color: color.withValues(
                                                    alpha: 0.4,
                                                  ),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                            ],
                                          ),
                                          child: isSelected
                                              ? const Icon(
                                                  LucideIcons.check,
                                                  size: 18,
                                                  color: Colors.white,
                                                )
                                              : null,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          Text(
                            'Quick Suggestions',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: suggestions.map((s) {
                              final fullTag = '${s['label']}|${s['color']}';
                              final isAdded = currentTags.contains(fullTag);
                              final color = _parseColor(
                                s['color'],
                                AppColors.primaryDark,
                              );

                              if (isAdded) return const SizedBox.shrink();

                              return ActionChip(
                                avatar: Icon(s['icon'], size: 14, color: color),
                                label: Text(
                                  s['label'],
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                                backgroundColor: color.withValues(alpha: 0.1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100),
                                  side: BorderSide(
                                    color: color.withValues(alpha: 0.2),
                                  ),
                                ),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  setSheetState(() => currentTags.add(fullTag));
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),

                  // Footer Actions
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border(
                        top: BorderSide(color: AppColors.cardBorder),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                              ),
                              side: const BorderSide(
                                color: AppColors.cardBorder,
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _updateProduct({'detailTags': currentTags});
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryDark,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Apply Badges',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddReviewDialog() {
    final nameController = TextEditingController();
    final commentController = TextEditingController();
    double rating = 5.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Add Manual Review',
            style: GoogleFonts.playfairDisplay(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Reviewer Name (Optional - defaults to Customer)',
                    labelStyle: GoogleFonts.inter(color: AppColors.textMuted),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.cardBorder),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primaryDark),
                    ),
                  ),
                  style: GoogleFonts.inter(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),
                Text(
                  'Rating: ${rating.toInt()} Stars',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Slider(
                  value: rating,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  onChanged: (val) => setDialogState(() => rating = val),
                  activeColor: const Color(0xFFF59E0B),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  decoration: InputDecoration(
                    labelText: 'Comment (Optional - leave empty for rating only)',
                    labelStyle: GoogleFonts.inter(color: AppColors.textMuted),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.cardBorder),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primaryDark),
                    ),
                  ),
                  maxLines: 3,
                  style: GoogleFonts.inter(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim().isEmpty 
                    ? 'Customer' 
                    : nameController.text.trim();
                final comment = commentController.text.trim();
                Navigator.pop(ctx);

                setState(() => _isLoading = true);
                try {
                  final client = ApiClient(
                    token: context.read<AuthProvider>().token,
                  );
                  await client.post(
                    '/api/admin/auth/reviews',
                    body: {
                      'name': name,
                      'rating': rating.toInt(),
                      'text': comment,
                      'productId': _product['id'],
                      'featured': false,
                    },
                  );
                  _snack('Review added successfully', ok: true);
                  _loadReviews();
                } catch (e) {
                  _snack('Failed to add review: $e');
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Add',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final priceRaw = _product['price'];
    final priceNum = priceRaw is String
        ? num.tryParse(priceRaw)
        : priceRaw as num?;
    final price = priceNum?.toStringAsFixed(0) ?? '0';

    final compRaw = _product['compareAtPrice'];
    final compareAtNum = compRaw is String
        ? num.tryParse(compRaw)
        : compRaw as num?;
    final compareAt = compareAtNum?.toStringAsFixed(0);

    final stockRaw = _product['totalStock'] ?? _product['stock'];
    final stock =
        (stockRaw is String ? int.tryParse(stockRaw) : stockRaw as int?) ?? 0;

    final String status = _product['status'] ?? 'draft';
    final Color statusColor = status == 'active'
        ? AppColors.success
        : (status == 'draft' ? AppColors.warning : AppColors.textMuted);

    final String? imageUrl = _product['imageUrl'];
    final List<dynamic> gallery = _product['images'] ?? [];

    final List<dynamic> variants = _product['variants'] ?? [];
    final String sku =
        (variants.isNotEmpty ? variants[0]['sku'] : _product['sku']) ?? 'N/A';

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refreshProduct,
              color: AppColors.primaryDark,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                SliverAppBar(
                  expandedHeight: 320,
                  pinned: true,
                  backgroundColor: AppColors.background,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                  ),
                  leading: IconButton(
                    icon: CircleAvatar(
                      backgroundColor: Colors.white.withValues(alpha: 0.8),
                      child: const Icon(
                        LucideIcons.arrowLeft,
                        color: AppColors.primaryDark,
                        size: 20,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    IconButton(
                      icon: CircleAvatar(
                        backgroundColor: Colors.white.withValues(alpha: 0.8),
                        child: const Icon(
                          LucideIcons.edit2,
                          color: AppColors.primaryDark,
                          size: 20,
                        ),
                      ),
                      onPressed: _navigateToEdit,
                    ),
                    const SizedBox(width: 8),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(24),
                    child: Container(
                      height: 32,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                      ),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: imageUrl != null
                        ? CachedNetworkImage(
                            cacheManager: AppImageCacheManager.instance,
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: AppColors.shimmer),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.shimmer,
                              child: const Icon(
                                LucideIcons.imageOff,
                                size: 48,
                                color: AppColors.textMuted,
                              ),
                            ),
                          )
                        : Container(
                            color: AppColors.shimmer,
                            child: const Icon(
                              LucideIcons.package,
                              size: 64,
                              color: AppColors.textMuted,
                            ),
                          ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Info
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _product['name'] ?? 'Unnamed Product',
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDark,
                                      height: 1.2,
                                    ),
                                  ),
                                  if ((_product['detailTags'] as List?)
                                              ?.isNotEmpty ==
                                          true ||
                                      (compareAtNum != null &&
                                          compareAtNum > (priceNum ?? 0))) ...[
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        if (compareAtNum != null &&
                                            compareAtNum > (priceNum ?? 0))
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEF4444),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFFEF4444,
                                                  ).withValues(alpha: 0.2),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  LucideIcons.flame,
                                                  size: 12,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '-${(((compareAtNum - (priceNum ?? 0)) / compareAtNum) * 100).round()}%',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ...(_product['detailTags'] as List? ??
                                                [])
                                            .map((tagRaw) {
                                              final tagStr = tagRaw.toString();
                                              if (tagStr.isEmpty) {
                                                return const SizedBox.shrink();
                                              }
                                              String label = tagStr;
                                              Color badgeColor =
                                                  AppColors.primaryDark;
                                              if (tagStr.contains('|')) {
                                                final parts = tagStr.split('|');
                                                label = parts[0];
                                                if (parts.length > 1 &&
                                                    parts[1].isNotEmpty) {
                                                  badgeColor = _parseColor(
                                                    parts[1],
                                                    AppColors.primaryDark,
                                                  );
                                                }
                                              }
                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: badgeColor,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: badgeColor
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),
                                                      blurRadius: 4,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      LucideIcons.sparkles,
                                                      size: 12,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      label.toUpperCase(),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Colors.white,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$price EGP',
                                  style: GoogleFonts.inter(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                if (compareAt != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '$compareAt EGP',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textMuted,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'In Stock',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                Text(
                                  '$stock Units',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: stock > 0
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Quick Actions (Controls requested by User)
                        _buildSectionTitle('Quick Controls', LucideIcons.zap),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionCard(
                                title: 'Add Stock',
                                subtitle: '$stock in stock',
                                icon: LucideIcons.packagePlus,
                                color: const Color(0xFF3B82F6),
                                onTap: _showStockDialog,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionCard(
                                title: 'Discount',
                                subtitle:
                                    (compareAtNum != null &&
                                        compareAtNum > (priceNum ?? 0))
                                    ? '-${(((compareAtNum - (priceNum ?? 0)) / compareAtNum) * 100).round()}% Active'
                                    : 'Apply offer',
                                icon: LucideIcons.tag,
                                color: const Color(0xFFF59E0B),
                                onTap: _showDiscountBottomSheet,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionCard(
                                title: 'Badge',
                                subtitle:
                                    (_product['detailTags'] as List?)
                                            ?.isNotEmpty ==
                                        true
                                    ? '${(_product['detailTags'] as List).length} active'
                                    : 'e.g. New',
                                icon: LucideIcons.sparkles,
                                color: const Color(0xFF8B5CF6),
                                onTap: _showBadgeBottomSheet,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Specifications Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryDark.withValues(
                                  alpha: 0.03,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle(
                                'Organization',
                                LucideIcons.folderTree,
                              ),
                              const SizedBox(height: 16),
                              _buildDetailRow(
                                'Category',
                                _product['category'] ??
                                    _product['categoryRel']?['name'] ??
                                    'N/A',
                              ),
                              const Divider(
                                height: 24,
                                color: AppColors.cardBorder,
                              ),
                              _buildDetailRow(
                                'Brand',
                                _product['brand']?['name'] ?? 'N/A',
                              ),
                              const Divider(
                                height: 24,
                                color: AppColors.cardBorder,
                              ),
                              _buildDetailRow(
                                'Material',
                                _product['material']?['name'] ?? 'N/A',
                              ),
                              const Divider(
                                height: 24,
                                color: AppColors.cardBorder,
                              ),
                              _buildDetailRow('SKU', sku),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Compact Information Tabs (Overview, Details, Specs)
                        _buildSectionTitle('Information', LucideIcons.info),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryDark.withValues(
                                  alpha: 0.03,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                height: 50,
                                margin: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  0,
                                ),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.cardBorder,
                                  ),
                                ),
                                child: TabBar(
                                  controller: _infoTabController,
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  dividerColor: Colors.transparent,
                                  indicator: BoxDecoration(
                                    color: AppColors.primaryDark,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  labelColor: Colors.white,
                                  unselectedLabelColor: AppColors.textMuted,
                                  labelStyle: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  unselectedLabelStyle: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  tabs: const [
                                    Tab(text: 'Overview'),
                                    Tab(text: 'Details'),
                                    Tab(text: 'Specs'),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: 220,
                                child: TabBarView(
                                  controller: _infoTabController,
                                  children: [
                                    _buildTabText(
                                      _product['description']
                                                  ?.toString()
                                                  .isNotEmpty ==
                                              true
                                          ? _product['description']
                                          : 'No overview available.',
                                    ),
                                    _buildTabText(
                                      _product['detailedDescription']
                                                  ?.toString()
                                                  .isNotEmpty ==
                                              true
                                          ? _product['detailedDescription']
                                          : 'No details available.',
                                    ),
                                    _buildSpecsContent(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Gallery
                        if (gallery.isNotEmpty) ...[
                          _buildSectionTitle('Gallery', LucideIcons.image),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: gallery.length,
                              itemBuilder: (context, index) {
                                final img = gallery[index]['url'];
                                return Container(
                                  width: 100,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.cardBorder,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      cacheManager:
                                          AppImageCacheManager.instance,
                                      imageUrl: img,
                                      fit: BoxFit.cover,
                                      placeholder: (ctx, url) =>
                                          Container(color: AppColors.shimmer),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                        // Reviews Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSectionTitle(
                              'Customer Reviews',
                              LucideIcons.star,
                            ),
                            TextButton.icon(
                              onPressed: () => _showAddReviewDialog(),
                              icon: const Icon(LucideIcons.plus, size: 16),
                              label: const Text('Add'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primaryDark,
                                textStyle: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 120,
                          child: _reviews.isEmpty
                              ? Center(
                                  child: Text(
                                    'No reviews for this product.',
                                    style: GoogleFonts.inter(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _reviews.length,
                                  itemBuilder: (context, index) {
                                    final r = _reviews[index];
                                    return Container(
                                      width: 280,
                                      margin: const EdgeInsets.only(right: 12),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AppColors.cardBorder,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: List.generate(
                                                  5,
                                                  (starIndex) => Icon(
                                                    LucideIcons.star,
                                                    size: 14,
                                                    color:
                                                        starIndex <
                                                            (r['rating'] ?? 0)
                                                        ? const Color(
                                                            0xFFF59E0B,
                                                          )
                                                        : AppColors.textMuted
                                                              .withValues(
                                                                alpha: 0.3,
                                                              ),
                                                  ),
                                                ),
                                              ),
                                              const Icon(
                                                LucideIcons.messageSquare,
                                                size: 16,
                                                color: AppColors.textMuted,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            r['reviewerName'] ?? 'Anonymous',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Expanded(
                                            child: Text(
                                              r['comment'] ?? '',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                                height: 1.4,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Positioned(
                top: MediaQuery.of(context).padding.top + 56,
                left: 0,
                right: 0,
                child: const LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryDark),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTabText(String text) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textSecondary,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildSpecsContent() {
    final specs = _product['specs'] as Map<String, dynamic>? ?? {};
    if (specs.isEmpty) {
      return Center(
        child: Text(
          'No specifications provided.',
          style: GoogleFonts.inter(color: AppColors.textMuted),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: specs.entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    _formatKey(e.key),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    e.value.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatKey(String key) {
    if (key.isEmpty) return key;
    final text = key.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => ' ${match.group(0)}',
    );
    return text[0].toUpperCase() + text.substring(1);
  }

  Color _parseColor(String? hexString, Color fallback) {
    if (hexString == null || hexString.isEmpty) return fallback;
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return fallback;
    }
  }
}


