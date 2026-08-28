import 'package:admin_app/core/services/app_image_cache_manager.dart';
import 'package:admin_app/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:admin_app/core/config/api_config.dart';
import '../../../core/widgets/app_shimmer.dart';

enum OrganizeType { category, brand, material }

class OrganizeProductsScreen extends StatefulWidget {
  final String entityId;
  final String entityName;
  final OrganizeType type;

  const OrganizeProductsScreen({
    super.key,
    required this.entityId,
    required this.entityName,
    required this.type,
  });

  @override
  State<OrganizeProductsScreen> createState() => _OrganizeProductsScreenState();
}

class _OrganizeProductsScreenState extends State<OrganizeProductsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _products = [];
  bool _useCustomOrder = false;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;

  String get _apiPath {
    switch (widget.type) {
      case OrganizeType.category:
        return '/api/admin/auth/categories/${widget.entityId}/products';
      case OrganizeType.brand:
        return '/api/admin/auth/brands/${widget.entityId}/products';
      case OrganizeType.material:
        return '/api/admin/auth/materials/${widget.entityId}/products';
    }
  }

  String get _typeLabel {
    switch (widget.type) {
      case OrganizeType.category:
        return 'Category';
      case OrganizeType.brand:
        return 'Brand';
      case OrganizeType.material:
        return 'Material';
    }
  }

  IconData get _typeIcon {
    switch (widget.type) {
      case OrganizeType.category:
        return LucideIcons.layoutGrid;
      case OrganizeType.brand:
        return LucideIcons.tag;
      case OrganizeType.material:
        return LucideIcons.layers;
    }
  }

  Color get _accentColor {
    switch (widget.type) {
      case OrganizeType.category:
        return const Color(0xFF3B82F6);
      case OrganizeType.brand:
        return const Color(0xFF8B5CF6);
      case OrganizeType.material:
        return const Color(0xFF64748B);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final client = ApiClient(token: context.read<AuthProvider>().token);
      final data = await client.get(_apiPath);
      if (!mounted) return;
      setState(() {
        _products = List<Map<String, dynamic>>.from(data['products'] ?? []);
        _useCustomOrder = data['entity']?['useCustomOrder'] == true;
        _hasUnsavedChanges = false;
        _isSaving = false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveOrder() async {
    setState(() => _isSaving = true);
    try {
      final client = ApiClient(token: context.read<AuthProvider>().token);
      final items = _products
          .asMap()
          .entries
          .map((e) => {'id': e.value['id'], 'sortOrder': e.key})
          .toList();
      await client.put(
        _apiPath,
        body: {'items': items, 'useCustomOrder': _useCustomOrder},
      );
      if (!mounted) return;
      setState(() {
        _hasUnsavedChanges = false;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showAppToast(
        AppToast.snackBar(
          content: Row(
            children: [
              const Icon(
                LucideIcons.checkCircle,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Order saved & synced to website',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showAppToast(
        AppToast.snackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toggleOrderMode(bool value) {
    setState(() {
      _useCustomOrder = value;
      _hasUnsavedChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            expandedHeight: 180,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            leading: IconButton(
              icon: const Icon(
                LucideIcons.arrowLeft,
                color: AppColors.primaryDark,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              widget.entityName,
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
            actions: [
              if (_hasUnsavedChanges)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: TextButton.icon(
                    onPressed: _isSaving ? null : _saveOrder,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.save, size: 18),
                    label: const Text('Save'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                    ),
                  ),
                ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(120),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    // Entity info chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_typeIcon, size: 14, color: _accentColor),
                          const SizedBox(width: 6),
                          Text(
                            '$_typeLabel • ${_products.length} products',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Order mode toggle
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _useCustomOrder
                                  ? AppColors.success.withValues(alpha: 0.1)
                                  : AppColors.textMuted.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _useCustomOrder
                                  ? LucideIcons.listOrdered
                                  : LucideIcons.shuffle,
                              size: 18,
                              color: _useCustomOrder
                                  ? AppColors.success
                                  : AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _useCustomOrder
                                      ? 'Custom Order'
                                      : 'Random Order',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                Text(
                                  _useCustomOrder
                                      ? 'Products appear in your set order on website'
                                      : 'Products appear randomly on website',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _useCustomOrder,
                            onChanged: _toggleOrderMode,
                            activeTrackColor: AppColors.success,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: _isLoading
            ? ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: 6,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const AppShimmer(
                          width: 56,
                          height: 56,
                          borderRadius: 12,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              AppShimmer(width: 140, height: 14),
                              SizedBox(height: 6),
                              AppShimmer(width: 80, height: 12),
                            ],
                          ),
                        ),
                        const AppShimmer(
                          width: 20,
                          height: 20,
                          borderRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.alertCircle,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: GoogleFonts.inter(color: AppColors.error),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadProducts,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _products.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _accentColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.package,
                        size: 48,
                        color: _accentColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Products',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No products are assigned to this $_typeLabel yet.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadProducts,
                color: AppColors.primaryDark,
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _products.length,
                  buildDefaultDragHandles: _useCustomOrder,
                  proxyDecorator: (child, index, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        final animValue = Curves.easeInOut.transform(
                          animation.value,
                        );
                        final elevation = 8.0 * animValue;
                        final scale = 1.0 + 0.02 * animValue;
                        return Transform.scale(
                          scale: scale,
                          child: Material(
                            elevation: elevation,
                            borderRadius: BorderRadius.circular(16),
                            shadowColor: _accentColor.withValues(alpha: 0.3),
                            color: Colors.transparent,
                            child: child,
                          ),
                        );
                      },
                      child: child,
                    );
                  },
                  onReorder: (oldIndex, newIndex) {
                    if (!_useCustomOrder) return;
                    HapticFeedback.lightImpact();
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = _products.removeAt(oldIndex);
                      _products.insert(newIndex, item);
                      _hasUnsavedChanges = true;
                    });
                  },
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    final name = product['name'] ?? 'Unnamed';
                    final imageUrl = product['imageUrl'];
                    final price = product['price'];
                    final stock = product['stock'] ?? 0;
                    final status = product['status'] ?? 'draft';
                    final sku = product['sku'] ?? '';

                    return Padding(
                      key: ValueKey(product['id']),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.cardBorder),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryDark.withValues(
                                alpha: 0.02,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Order number
                              if (_useCustomOrder)
                                Container(
                                  width: 28,
                                  height: 28,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    color: _accentColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _accentColor,
                                      ),
                                    ),
                                  ),
                                ),
                              // Product image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 52,
                                  height: 52,
                                  child:
                                      imageUrl != null &&
                                          imageUrl.toString().isNotEmpty
                                      ? CachedNetworkImage(
                                          cacheManager:
                                              AppImageCacheManager.instance,
                                          imageUrl: imageUrl.startsWith('http')
                                              ? imageUrl
                                              : '${ApiConfig.baseUrl}$imageUrl',
                                          fit: BoxFit.cover,
                                          placeholder: (_, _) => Container(
                                            color: AppColors.background,
                                            child: const Center(
                                              child: SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color:
                                                          AppColors.textMuted,
                                                    ),
                                              ),
                                            ),
                                          ),
                                          errorWidget: (_, _, _) => Container(
                                            color: AppColors.background,
                                            child: const Icon(
                                              LucideIcons.image,
                                              color: AppColors.textMuted,
                                              size: 20,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          color: AppColors.background,
                                          child: const Icon(
                                            LucideIcons.image,
                                            color: AppColors.textMuted,
                                            size: 20,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Product info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primaryDark,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '${price is num ? price.toStringAsFixed(0) : price} EGP',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: AppColors.textMuted,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '$stock in stock',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: stock > 0
                                                ? AppColors.success
                                                : AppColors.error,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (sku.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          'SKU: $sku',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Status + drag handle
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: status == 'active'
                                          ? AppColors.success.withValues(
                                              alpha: 0.1,
                                            )
                                          : AppColors.warning.withValues(
                                              alpha: 0.1,
                                            ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      status == 'active' ? 'Active' : 'Draft',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: status == 'active'
                                            ? AppColors.success
                                            : AppColors.warning,
                                      ),
                                    ),
                                  ),
                                  if (_useCustomOrder) ...[
                                    const SizedBox(height: 6),
                                    Icon(
                                      LucideIcons.gripVertical,
                                      size: 18,
                                      color: AppColors.textMuted.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
