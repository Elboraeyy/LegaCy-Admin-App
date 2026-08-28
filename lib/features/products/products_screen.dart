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
import 'package:admin_app/features/products/add_product_screen.dart';
import 'package:admin_app/features/products/add_batch_screen.dart';
import 'package:admin_app/features/products/product_details_screen.dart';
import 'package:admin_app/core/config/api_config.dart';

import '../storefront/screens/categories_screen.dart';
import '../storefront/screens/brands_screen.dart';
import '../storefront/screens/materials_screen.dart';
import '../storefront/screens/merchandising_screen.dart';
import '../../core/widgets/app_shimmer.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  List<dynamic> _allProducts = [];
  List<dynamic> _products = [];
  bool _isLoading = true;
  String? _error;
  String _statusFilter = 'all';
  String _sortFilter = 'newest';
  String _stockFilter = 'all';
  String? _categoryFilter;
  String? _brandFilter;
  String? _materialFilter;
  bool _selectionMode = false;

  bool get _hasActiveFilters =>
      _statusFilter != 'all' ||
      _sortFilter != 'newest' ||
      _stockFilter != 'all' ||
      _categoryFilter != null ||
      _brandFilter != null ||
      _materialFilter != null;

  List<Map<String, String>> get _availableCategories {
    final map = <String, String>{};
    for (var p in _allProducts) {
      final cat = p['categoryRel'];
      if (cat != null && cat['id'] != null) {
        map[cat['id'].toString()] = cat['name']?.toString() ?? 'Unknown';
      } else if (p['category'] != null) {
        map[p['category'].toString()] = p['category'].toString();
      }
    }
    return map.entries.map((e) => {'id': e.key, 'name': e.value}).toList();
  }

  List<Map<String, String>> get _availableBrands {
    final map = <String, String>{};
    for (var p in _allProducts) {
      final b = p['brand'];
      if (b != null && b['id'] != null) {
        map[b['id'].toString()] = b['name']?.toString() ?? 'Unknown';
      }
    }
    return map.entries.map((e) => {'id': e.key, 'name': e.value}).toList();
  }

  List<Map<String, String>> get _availableMaterials {
    final map = <String, String>{};
    for (var p in _allProducts) {
      final m = p['material'];
      if (m != null && m['id'] != null) {
        map[m['id'].toString()] = m['name']?.toString() ?? 'Unknown';
      }
    }
    return map.entries.map((e) => {'id': e.key, 'name': e.value}).toList();
  }

  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_selectionMode) _exitSelection();
        setState(() {}); // to update FAB visibility
      }
    });
    _loadProducts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      String path = '${ApiConfig.authProductsEndpoint}?limit=1000';
      if (_searchController.text.isNotEmpty) {
        path += '&search=${Uri.encodeComponent(_searchController.text)}';
      }
      final data = await client.get(path);
      if (mounted) {
        _allProducts = data['products'] as List<dynamic>;
        _applyLocalFilters();
        setState(() {
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

  void _applyLocalFilters() {
    List<dynamic> filtered = List.from(_allProducts);

    // Status Filter
    if (_statusFilter != 'all') {
      filtered = filtered.where((p) => p['status'] == _statusFilter).toList();
    }

    // Stock Filter
    if (_stockFilter != 'all') {
      filtered = filtered.where((p) {
        final stock = (p['totalStock'] as num?)?.toInt() ?? 0;
        if (_stockFilter == 'in_stock') return stock > 0;
        if (_stockFilter == 'low_stock') return stock > 0 && stock <= 5;
        if (_stockFilter == 'out_of_stock') return stock <= 0;
        return true;
      }).toList();
    }

    // Category Filter
    if (_categoryFilter != null) {
      filtered = filtered
          .where(
            (p) =>
                p['categoryRel']?['id'] == _categoryFilter ||
                p['categoryId'] == _categoryFilter ||
                p['category'] == _categoryFilter,
          )
          .toList();
    }

    // Brand Filter
    if (_brandFilter != null) {
      filtered = filtered
          .where(
            (p) =>
                p['brand']?['id'] == _brandFilter ||
                p['brandId'] == _brandFilter,
          )
          .toList();
    }

    // Material Filter
    if (_materialFilter != null) {
      filtered = filtered
          .where(
            (p) =>
                p['material']?['id'] == _materialFilter ||
                p['materialId'] == _materialFilter,
          )
          .toList();
    }

    // Sort
    filtered.sort((a, b) {
      if (_sortFilter == 'newest') {
        final dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
        final dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
        return dateB.compareTo(dateA);
      } else if (_sortFilter == 'oldest') {
        final dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
        final dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
        return dateA.compareTo(dateB);
      } else if (_sortFilter == 'price_asc') {
        final priceA = num.tryParse(a['price']?.toString() ?? '0') ?? 0;
        final priceB = num.tryParse(b['price']?.toString() ?? '0') ?? 0;
        return priceA.compareTo(priceB);
      } else if (_sortFilter == 'price_desc') {
        final priceA = num.tryParse(a['price']?.toString() ?? '0') ?? 0;
        final priceB = num.tryParse(b['price']?.toString() ?? '0') ?? 0;
        return priceB.compareTo(priceA);
      } else if (_sortFilter == 'name_asc') {
        final nameA = (a['name'] ?? '').toString().toLowerCase();
        final nameB = (b['name'] ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB);
      } else if (_sortFilter == 'name_desc') {
        final nameA = (a['name'] ?? '').toString().toLowerCase();
        final nameB = (b['name'] ?? '').toString().toLowerCase();
        return nameB.compareTo(nameA);
      }
      return 0;
    });

    if (mounted) {
      setState(() {
        _products = filtered;
      });
    }
  }

  Future<void> _updateProductStatus(String id, String status) async {
    setState(() => _isLoading = true);
    try {
      if (!mounted) return;
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final body = <String, dynamic>{
        'action': 'update_status',
        'ids': [id],
        'status': status,
      };
      await client.post('${ApiConfig.authProductsEndpoint}/bulk', body: body);
      if (mounted) {
        _showSnack(
          'Status updated to ${status.toUpperCase()}',
          isSuccess: true,
        );
        _loadProducts();
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to update status: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleSelection(String id) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
        _selectionMode = true;
      }
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _bulkAction(String action, {String? status}) async {
    if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => _buildConfirmDialog(
          title: 'Delete ${_selectedIds.length} Products?',
          message: 'This action cannot be undone.',
          confirmLabel: 'Delete All',
          isDestructive: true,
        ),
      );
      if (ok != true) return;
    }

    setState(() => _isLoading = true);
    try {
      if (!mounted) return;
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final body = <String, dynamic>{
        'action': action == 'delete' ? 'delete' : 'update_status',
        'ids': _selectedIds.toList(),
      };
      if (status != null) body['status'] = status;
      await client.post('${ApiConfig.authProductsEndpoint}/bulk', body: body);
      if (mounted) {
        _showSnack(
          action == 'delete' ? 'Products deleted' : 'Status updated',
          isSuccess: true,
        );
        _exitSelection();
        _loadProducts();
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showAppToast(
      AppToast.snackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: isSuccess ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        title,
        style: GoogleFonts.playfairDisplay(
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
        ),
      ),
      content: Text(
        message,
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
      ),
      actions: [
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
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDestructive
                ? AppColors.error
                : AppColors.primaryDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.surface,
                surfaceTintColor: Colors.transparent,
                expandedHeight: _selectionMode ? 60 : 130,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                leading: _selectionMode
                    ? IconButton(
                        icon: const Icon(
                          LucideIcons.x,
                          color: AppColors.primaryDark,
                        ),
                        onPressed: _exitSelection,
                      )
                    : null,
                title: _selectionMode
                    ? Text(
                        '${_selectedIds.length} selected',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      )
                    : Text(
                        'Catalog',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                actions: _selectionMode
                    ? [
                        IconButton(
                          icon: Icon(
                            _selectedIds.length == _products.length
                                ? LucideIcons.checkSquare
                                : LucideIcons.square,
                            color: AppColors.primaryDark,
                          ),
                          onPressed: () {
                            setState(() {
                              if (_selectedIds.length == _products.length) {
                                _selectedIds.clear();
                                _selectionMode = false;
                              } else {
                                _selectedIds.addAll(
                                  _products.map((p) => p['id'].toString()),
                                );
                              }
                            });
                          },
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(
                            LucideIcons.moreVertical,
                            color: AppColors.primaryDark,
                          ),
                          onSelected: (v) => v == 'delete'
                              ? _bulkAction('delete')
                              : _bulkAction('status', status: v),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'active',
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.success,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text('Set Active'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'draft',
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.warning,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text('Set Draft'),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.trash2,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ]
                    : [
                        if (_tabController.index == 0)
                          IconButton(
                            icon: const Icon(
                              LucideIcons.checkSquare,
                              size: 20,
                              color: AppColors.primaryDark,
                            ),
                            onPressed: () =>
                                setState(() => _selectionMode = true),
                          ),
                        const SizedBox(width: 8),
                      ],
                bottom: _selectionMode
                    ? null
                    : PreferredSize(
                        preferredSize: const Size.fromHeight(60),
                        child: Container(
                          height: 50,
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            indicator: BoxDecoration(
                              color: AppColors.primaryDark,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: AppColors.textMuted,
                            labelStyle: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            unselectedLabelStyle: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            tabs: const [
                              Tab(text: 'Products'),
                              Tab(text: 'Organize'),
                            ],
                          ),
                        ),
                      ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Products
              _buildProductsTab(),
              // Tab 2: Storefront
              _buildStorefrontTab(),
            ],
          ),
        ),
        floatingActionButton: _selectionMode || _tabController.index != 0
            ? null
            : Padding(
                padding: const EdgeInsets.only(bottom: 90),
                child: FloatingActionButton.extended(
                  onPressed: _showAddOptions,
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  icon: const Icon(LucideIcons.plus, size: 20),
                  label: Text(
                    'New Product',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
      ),
    );
  }

  void _showAddOptions() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Product',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'What would you like to do?',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildAddOption(
                        icon: LucideIcons.packagePlus,
                        title: 'New Product',
                        subtitle: 'Create a brand new product from scratch',
                        onTap: () {
                          Navigator.pop(ctx);
                          _navigateToAddProduct();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAddOption(
                        icon: LucideIcons.boxes,
                        title: 'New Batch',
                        subtitle:
                            'Add new quantity to a product you already sell',
                        onTap: () {
                          Navigator.pop(ctx);
                          _navigateToAddBatch();
                        },
                      ),
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

  Widget _buildAddOption({
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primaryDark, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.primaryDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToAddProduct() async {
    HapticFeedback.mediumImpact();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddProductScreen()),
    );
    if (result == true) _loadProducts();
  }

  Future<void> _navigateToAddBatch() async {
    HapticFeedback.mediumImpact();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddBatchScreen()),
    );
    if (result == true) _loadProducts();
  }

  Widget _buildProductsTab() {
    return RefreshIndicator(
      onRefresh: _loadProducts,
      color: AppColors.primaryDark,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Search + Filter Bar ──
          if (!_selectionMode)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.cardBorder),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryDark.withValues(
                                alpha: 0.03,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onSubmitted: (_) => _loadProducts(),
                          style: GoogleFonts.inter(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search products...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                            prefixIcon: const Icon(
                              LucideIcons.search,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(LucideIcons.x, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      _loadProducts();
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _showFilterSortSheet,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _hasActiveFilters
                                ? AppColors.accent
                                : AppColors.cardBorder,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryDark.withValues(
                                alpha: 0.03,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          LucideIcons.slidersHorizontal,
                          size: 18,
                          color: _hasActiveFilters
                              ? AppColors.accent
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Status filter chips ──
          if (!_selectionMode)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _chip('All', 'all'),
                            const SizedBox(width: 6),
                            _chip('Active', 'active'),
                            const SizedBox(width: 6),
                            _chip('Draft', 'draft'),
                            const SizedBox(width: 6),
                            _chip('Archived', 'archived'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_products.length} items',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Content ──
          _isLoading
              ? SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.62,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildProductSkeleton(),
                      childCount: 6,
                    ),
                  ),
                )
              : _error != null
              ? SliverFillRemaining(child: _buildErrorState())
              : _products.isEmpty
              ? SliverFillRemaining(child: _buildEmptyState())
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.62,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildProductCard(_products[index]),
                      childCount: _products.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildStorefrontTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        _buildStorefrontCard(
          title: 'Categories',
          subtitle: 'Manage product hierarchy and collections',
          icon: LucideIcons.layoutGrid,
          color: const Color(0xFF3B82F6),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CategoriesScreen()),
          ),
        ),
        const SizedBox(height: 16),

        _buildStorefrontCard(
          title: 'Brands',
          subtitle: 'Manage partner brands and manufacturers',
          icon: LucideIcons.tag,
          color: const Color(0xFF8B5CF6),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BrandsScreen()),
          ),
        ),
        const SizedBox(height: 16),

        _buildStorefrontCard(
          title: 'Materials',
          subtitle: 'Configure product materials and care instructions',
          icon: LucideIcons.layers,
          color: const Color(0xFF64748B),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MaterialsScreen()),
          ),
        ),
        const SizedBox(height: 16),

        _buildStorefrontCard(
          title: 'Home & Shop Products',
          subtitle: 'Control featured, new arrivals, and shop ordering',
          icon: LucideIcons.slidersHorizontal,
          color: AppColors.primaryDark,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MerchandisingScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildStorefrontCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
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
              color: AppColors.cardBorder.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 24, color: color),
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
            Icon(
              LucideIcons.chevronRight,
              size: 20,
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSortSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filter & Sort',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.x),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Sort By
                              Text(
                                'Sort By',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _sortChipSheet(
                                    'Newest',
                                    'newest',
                                    setSheetState,
                                  ),
                                  _sortChipSheet(
                                    'Oldest',
                                    'oldest',
                                    setSheetState,
                                  ),
                                  _sortChipSheet(
                                    'Price: Low to High',
                                    'price_asc',
                                    setSheetState,
                                  ),
                                  _sortChipSheet(
                                    'Price: High to Low',
                                    'price_desc',
                                    setSheetState,
                                  ),
                                  _sortChipSheet(
                                    'Name: A-Z',
                                    'name_asc',
                                    setSheetState,
                                  ),
                                  _sortChipSheet(
                                    'Name: Z-A',
                                    'name_desc',
                                    setSheetState,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Status
                              Text(
                                'Status',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _filterChipSheet('All', 'all', setSheetState),
                                  _filterChipSheet(
                                    'Active',
                                    'active',
                                    setSheetState,
                                  ),
                                  _filterChipSheet(
                                    'Draft',
                                    'draft',
                                    setSheetState,
                                  ),
                                  _filterChipSheet(
                                    'Archived',
                                    'archived',
                                    setSheetState,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Stock Level
                              Text(
                                'Stock Level',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _stockChipSheet('All', 'all', setSheetState),
                                  _stockChipSheet(
                                    'In Stock',
                                    'in_stock',
                                    setSheetState,
                                  ),
                                  _stockChipSheet(
                                    'Low Stock',
                                    'low_stock',
                                    setSheetState,
                                  ),
                                  _stockChipSheet(
                                    'Out of Stock',
                                    'out_of_stock',
                                    setSheetState,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Category
                              if (_availableCategories.isNotEmpty) ...[
                                Text(
                                  'Category',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    border: Border.all(
                                      color: AppColors.cardBorder,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String?>(
                                      isExpanded: true,
                                      icon: const Icon(
                                        LucideIcons.chevronDown,
                                        color: AppColors.textMuted,
                                        size: 20,
                                      ),
                                      dropdownColor: AppColors.surface,
                                      borderRadius: BorderRadius.circular(16),
                                      elevation: 4,
                                      value: _categoryFilter,
                                      hint: Row(
                                        children: [
                                          const Icon(
                                            LucideIcons.layoutGrid,
                                            color: AppColors.textMuted,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'All Categories',
                                            style: GoogleFonts.inter(
                                              fontSize: 15,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                          value: null,
                                          child: Row(
                                            children: [
                                              const Icon(
                                                LucideIcons.layoutGrid,
                                                color: AppColors.textMuted,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'All Categories',
                                                style: GoogleFonts.inter(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ..._availableCategories.map(
                                          (c) => DropdownMenuItem(
                                            value: c['id'],
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primaryDark
                                                        .withValues(alpha: 0.1),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    LucideIcons.layoutGrid,
                                                    size: 14,
                                                    color:
                                                        AppColors.primaryDark,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  c['name']!,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppColors.primaryDark,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (v) => setSheetState(
                                        () => _categoryFilter = v,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],

                              // Brand
                              if (_availableBrands.isNotEmpty) ...[
                                Text(
                                  'Brand',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    border: Border.all(
                                      color: AppColors.cardBorder,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String?>(
                                      isExpanded: true,
                                      icon: const Icon(
                                        LucideIcons.chevronDown,
                                        color: AppColors.textMuted,
                                        size: 20,
                                      ),
                                      dropdownColor: AppColors.surface,
                                      borderRadius: BorderRadius.circular(16),
                                      elevation: 4,
                                      value: _brandFilter,
                                      hint: Row(
                                        children: [
                                          const Icon(
                                            LucideIcons.tag,
                                            color: AppColors.textMuted,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'All Brands',
                                            style: GoogleFonts.inter(
                                              fontSize: 15,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                          value: null,
                                          child: Row(
                                            children: [
                                              const Icon(
                                                LucideIcons.tag,
                                                color: AppColors.textMuted,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'All Brands',
                                                style: GoogleFonts.inter(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ..._availableBrands.map(
                                          (b) => DropdownMenuItem(
                                            value: b['id'],
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primaryDark
                                                        .withValues(alpha: 0.1),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    LucideIcons.tag,
                                                    size: 14,
                                                    color:
                                                        AppColors.primaryDark,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  b['name']!,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppColors.primaryDark,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (v) =>
                                          setSheetState(() => _brandFilter = v),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],

                              // Material
                              if (_availableMaterials.isNotEmpty) ...[
                                Text(
                                  'Material',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    border: Border.all(
                                      color: AppColors.cardBorder,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String?>(
                                      isExpanded: true,
                                      icon: const Icon(
                                        LucideIcons.chevronDown,
                                        color: AppColors.textMuted,
                                        size: 20,
                                      ),
                                      dropdownColor: AppColors.surface,
                                      borderRadius: BorderRadius.circular(16),
                                      elevation: 4,
                                      value: _materialFilter,
                                      hint: Row(
                                        children: [
                                          const Icon(
                                            LucideIcons.layers,
                                            color: AppColors.textMuted,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'All Materials',
                                            style: GoogleFonts.inter(
                                              fontSize: 15,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                          value: null,
                                          child: Row(
                                            children: [
                                              const Icon(
                                                LucideIcons.layers,
                                                color: AppColors.textMuted,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'All Materials',
                                                style: GoogleFonts.inter(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ..._availableMaterials.map(
                                          (m) => DropdownMenuItem(
                                            value: m['id'],
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primaryDark
                                                        .withValues(alpha: 0.1),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    LucideIcons.layers,
                                                    size: 14,
                                                    color:
                                                        AppColors.primaryDark,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  m['name']!,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppColors.primaryDark,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (v) => setSheetState(
                                        () => _materialFilter = v,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: OutlinedButton(
                              onPressed: () {
                                setSheetState(() {
                                  _statusFilter = 'all';
                                  _sortFilter = 'newest';
                                  _stockFilter = 'all';
                                  _categoryFilter = null;
                                  _brandFilter = null;
                                  _materialFilter = null;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                side: const BorderSide(
                                  color: AppColors.cardBorder,
                                ),
                              ),
                              child: Text(
                                'Reset',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
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
                                _applyLocalFilters();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryDark,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Apply Filters',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _stockChipSheet(
    String label,
    String value,
    StateSetter setSheetState,
  ) {
    final isActive = _stockFilter == value;
    return GestureDetector(
      onTap: () => setSheetState(() => _stockFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryDark : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primaryDark : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _filterChipSheet(
    String label,
    String value,
    StateSetter setSheetState,
  ) {
    final isActive = _statusFilter == value;
    return GestureDetector(
      onTap: () => setSheetState(() => _statusFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryDark : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primaryDark : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _sortChipSheet(String label, String value, StateSetter setSheetState) {
    final isActive = _sortFilter == value;
    return GestureDetector(
      onTap: () => setSheetState(() => _sortFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.accent : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    final isActive = _statusFilter == value;
    return GestureDetector(
      onTap: () {
        _statusFilter = value;
        _applyLocalFilters();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryDark : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primaryDark : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  void _showStatusPicker(Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Change Status',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  'Active',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                trailing: product['status'] == 'active'
                    ? const Icon(LucideIcons.check, color: AppColors.success)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  if (product['status'] != 'active') {
                    _updateProductStatus(product['id'], 'active');
                  }
                },
              ),
              ListTile(
                leading: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  'Draft',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                trailing: product['status'] == 'draft'
                    ? const Icon(LucideIcons.check, color: AppColors.warning)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  if (product['status'] != 'draft') {
                    _updateProductStatus(product['id'], 'draft');
                  }
                },
              ),
              ListTile(
                leading: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  'Archived',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                trailing: product['status'] == 'archived'
                    ? const Icon(LucideIcons.check, color: AppColors.textMuted)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  if (product['status'] != 'archived') {
                    _updateProductStatus(product['id'], 'archived');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductSkeleton() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image skeleton
          const Expanded(
            flex: 5,
            child: AppShimmer(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 19,
            ),
          ),
          // Info Section
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AppShimmer(width: 120, height: 14),
                  const AppShimmer(width: 80, height: 14),
                  const AppShimmer(width: 60, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const AppShimmer(width: 50, height: 20, borderRadius: 10),
                      const AppShimmer(width: 40, height: 12),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final isActive = product['status'] == 'active';
    final isSelected = _selectedIds.contains(product['id']);
    final priceRaw = product['price'];
    final priceNum = priceRaw is String
        ? num.tryParse(priceRaw)
        : priceRaw as num?;
    final price = priceNum?.toStringAsFixed(0) ?? '0';

    final compRaw = product['compareAtPrice'];
    final compareAt = compRaw is String
        ? num.tryParse(compRaw)
        : compRaw as num?;

    final stockRaw = product['totalStock'];
    final stock =
        (stockRaw is String ? int.tryParse(stockRaw) : stockRaw as int?) ?? 0;
    final List<dynamic> variants = product['variants'] ?? [];
    final skuRaw = variants.isNotEmpty ? variants[0]['sku'] : product['sku'];
    final sku = (skuRaw?.toString().trim().isNotEmpty ?? false)
        ? skuRaw.toString().trim()
        : 'N/A';

    final List<dynamic> detailTagsRaw = product['detailTags'] ?? [];
    List<Widget> badgeWidgets = [];

    if (compareAt != null && compareAt > (priceNum ?? 0)) {
      final discount = (((compareAt - (priceNum ?? 0)) / compareAt) * 100)
          .round();
      if (discount > 0) {
        badgeWidgets.add(
          _buildBadge(
            '-$discount%',
            const Color(0xFFEF4444),
            icon: LucideIcons.flame,
          ),
        );
      }
    }

    for (var tagRaw in detailTagsRaw) {
      final tagStr = tagRaw.toString();
      if (tagStr.isEmpty) continue;
      String label = tagStr;
      Color badgeColor = AppColors.primaryDark;
      if (tagStr.contains('|')) {
        final parts = tagStr.split('|');
        label = parts[0];
        if (parts.length > 1 && parts[1].isNotEmpty) {
          badgeColor = _parseColor(parts[1], AppColors.primaryDark);
        }
      }
      badgeWidgets.add(
        _buildBadge(
          label.toUpperCase(),
          badgeColor,
          icon: LucideIcons.sparkles,
        ),
      );
    }

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _toggleSelection(product['id']);
      },
      onTap: () {
        if (_selectionMode) {
          _toggleSelection(product['id']);
          return;
        }
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailsScreen(product: product),
          ),
        ).then((r) {
          if (r == true) _loadProducts();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.cardBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(
                alpha: isSelected ? 0.08 : 0.04,
              ),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Image ──
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(19),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        product['imageUrl'] != null
                            ? CachedNetworkImage(
                                cacheManager: AppImageCacheManager.instance,
                                imageUrl: product['imageUrl'],
                                fit: BoxFit.cover,
                                placeholder: (_, _) =>
                                    Container(color: AppColors.shimmer),
                                errorWidget: (_, _, _) => Container(
                                  color: AppColors.shimmer,
                                  child: const Center(
                                    child: Icon(
                                      LucideIcons.image,
                                      color: AppColors.textMuted,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                color: AppColors.shimmer,
                                child: Center(
                                  child: Icon(
                                    LucideIcons.image,
                                    color: AppColors.textMuted.withValues(
                                      alpha: 0.4,
                                    ),
                                    size: 36,
                                  ),
                                ),
                              ),
                        // Gradient overlay at bottom
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.15),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Info Section ──
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name'] ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'SKU: $sku',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        // Price Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (compareAt != null)
                                    Text(
                                      '${compareAt.toStringAsFixed(0)} EGP',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: AppColors.textMuted,
                                        decoration: TextDecoration.lineThrough,
                                        decorationColor: AppColors.textMuted,
                                      ),
                                    ),
                                  Text(
                                    '$price EGP',
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Stock badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: stock > 0
                                    ? AppColors.success.withValues(alpha: 0.08)
                                    : AppColors.error.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                stock > 0 ? '$stock' : 'Out',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: stock > 0
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Status Badge ──
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showStatusPicker(product);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primaryDark
                        : (product['status'] == 'archived'
                              ? AppColors.textMuted
                              : AppColors.warning),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    (product['status'] ?? 'UNKNOWN').toString().toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),

            // ── Badges ──
            if (badgeWidgets.isNotEmpty && !_selectionMode)
              Positioned(
                top: 10,
                left: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: badgeWidgets,
                ),
              ),

            // ── Selection Indicator ──
            if (_selectionMode)
              Positioned(
                top: 10,
                left: 10,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accent
                        : Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accent
                          : AppColors.cardBorder,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(
                          LucideIcons.check,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
          ],
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
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.package,
                size: 48,
                color: AppColors.accent.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Products Yet',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start building your catalog by\nadding your first product.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.wifiOff,
                size: 40,
                color: AppColors.error.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Failed to Load',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadProducts,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildBadge(String label, Color color, {IconData? icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
