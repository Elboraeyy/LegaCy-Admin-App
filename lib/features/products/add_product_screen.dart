import 'package:admin_app/core/services/app_image_cache_manager.dart';
import 'package:admin_app/core/widgets/app_toast.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:admin_app/core/config/api_config.dart';
import '../../core/widgets/app_shimmer.dart';

class AddProductScreen extends StatefulWidget {
  final Map<String, dynamic>? product;
  final bool returnResult;
  const AddProductScreen({super.key, this.product, this.returnResult = false});
  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  int get _totalSteps => 4;

  // Controllers (English only)
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _detailCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _compareCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _supplierPriceCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _metaTitleCtrl = TextEditingController();
  final _metaDescCtrl = TextEditingController();
  final _minStockCtrl = TextEditingController();

  // Specs
  final _dialSizeCtrl = TextEditingController();
  final _dialColorCtrl = TextEditingController();
  final _caseColorCtrl = TextEditingController();
  final _caseCtrl = TextEditingController();
  final _strapMatCtrl = TextEditingController();
  final _strapColCtrl = TextEditingController();
  final _strapWidthCtrl = TextEditingController();
  final _movementCtrl = TextEditingController();
  final _glassCtrl = TextEditingController();
  final _waterCtrl = TextEditingController();
  final _hourMarkersCtrl = TextEditingController();

  String? _catId, _brandId, _matId, _suppId;
  String _status = 'active';
  bool _newArrivals = true, _forYou = true;
  File? _imageFile;
  String? _imageUrl;
  List<String> _gallery = [];
  List<dynamic> _cats = [], _brands = [], _mats = [], _supps = [];

  List<Map<String, dynamic>> _relatedProducts = [];

  bool _loadingOpts = true, _saving = false;
  DateTime _purchaseDate = DateTime.now();

  bool get _isEdit => widget.product != null && widget.product!['id'] != null;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _prefill(widget.product!);
      _loadFullProduct(widget.product!['id']?.toString());
    }
    _loadOptions();
  }

  Future<void> _loadFullProduct(String? productId) async {
    if (productId == null) return;
    try {
      final client = ApiClient(token: context.read<AuthProvider>().token);
      final data = await client.get('/api/products/$productId');
      if (!mounted) return;

      final sim = data['similarProducts'] as List<dynamic>?;
      if (sim != null && sim.isNotEmpty) {
        setState(() {
          _relatedProducts = sim
              .map(
                (sp) => <String, dynamic>{
                  'id': sp['id'].toString(),
                  'name': sp['name'].toString(),
                  'image': sp['imageUrl']?.toString(),
                },
              )
              .toList();

          final order = data['orderedSimilarIds'] as List<dynamic>?;
          if (order != null && order.isNotEmpty) {
            _relatedProducts.sort((a, b) {
              final idxA = order.indexOf(a['id']);
              final idxB = order.indexOf(b['id']);
              if (idxA == -1 && idxB == -1) return 0;
              if (idxA == -1) return 1;
              if (idxB == -1) return -1;
              return idxA.compareTo(idxB);
            });
          }
        });
      }
    } catch (_) {
      // silently fail - similar products are optional
    }
  }

  void _prefill(Map<String, dynamic> p) {
    _nameCtrl.text = p['name'] ?? '';
    _descCtrl.text = p['description'] ?? '';
    _detailCtrl.text = p['detailedDescription'] ?? '';

    if (p['variants'] != null && (p['variants'] as List).isNotEmpty) {
      final v = p['variants'][0];
      _priceCtrl.text = v['price']?.toString() ?? '';
      _skuCtrl.text = v['sku'] ?? '';
    } else {
      _priceCtrl.text = p['price']?.toString() ?? '';
      _skuCtrl.text = p['sku'] ?? '';
    }
    _compareCtrl.text = p['compareAtPrice']?.toString() ?? '';
    _stockCtrl.text =
        p['stock']?.toString() ?? p['totalStock']?.toString() ?? '';

    String prefilledMinStock = '5';
    if (p['minStock'] != null) {
      prefilledMinStock = p['minStock'].toString();
    } else if (p['variants'] != null && (p['variants'] as List).isNotEmpty) {
      final v = p['variants'][0];
      if (v['inventory'] != null && (v['inventory'] as List).isNotEmpty) {
        final inv = v['inventory'][0];
        if (inv['minStock'] != null) {
          prefilledMinStock = inv['minStock'].toString();
        }
      }
    }
    _minStockCtrl.text = prefilledMinStock;

    _status = p['status'] ?? 'active';
    _catId = p['categoryId']?.toString() ?? p['categoryRel']?['id']?.toString();
    _brandId = p['brandId']?.toString() ?? p['brand']?['id']?.toString();
    _matId = p['materialId']?.toString() ?? p['material']?['id']?.toString();
    _suppId = p['supplierId']?.toString();

    _imageUrl = p['imageUrl'];
    if (p['images'] != null) {
      _gallery = (p['images'] as List).map((i) => i['url'].toString()).toList();
    }

    _newArrivals = p['showInNewArrivals'] ?? true;
    _forYou = p['showInForYou'] ?? true;
    _slugCtrl.text = p['slug'] ?? '';
    _metaTitleCtrl.text = p['metaTitle'] ?? '';
    _metaDescCtrl.text = p['metaDescription'] ?? '';

    final s = p['specs'];
    if (s != null) {
      _dialSizeCtrl.text = s['dialSize'] ?? '';
      _dialColorCtrl.text = s['dialColor'] ?? '';
      _caseColorCtrl.text = s['caseColor'] ?? '';
      _caseCtrl.text = s['case'] ?? '';
      _strapMatCtrl.text = s['strapMaterial'] ?? '';
      _strapColCtrl.text = s['strapColor'] ?? '';
      _strapWidthCtrl.text = s['strapWidth'] ?? '';
      _movementCtrl.text = s['movement'] ?? '';
      _glassCtrl.text = s['glass'] ?? '';
      _waterCtrl.text = s['waterResistance'] ?? '';
      _hourMarkersCtrl.text = s['hourMarkers'] ?? '';
      _supplierPriceCtrl.text = s['supplierPrice']?.toString() ?? '';
      _costCtrl.text = s['additionalCosts']?.toString() ?? '';
    }

    final sim = p['similarProducts'] as List<dynamic>?;
    if (sim != null) {
      _relatedProducts = sim
          .map(
            (sp) => <String, dynamic>{
              'id': sp['id'].toString(),
              'name': sp['name'].toString(),
              'image':
                  sp['imageUrl'] ??
                  (sp['images']?.isNotEmpty == true
                      ? sp['images'][0]['url']
                      : null),
            },
          )
          .toList();

      final order = p['orderedSimilarIds'] as List<dynamic>?;
      if (order != null && order.isNotEmpty) {
        _relatedProducts.sort((a, b) {
          final idxA = order.indexOf(a['id']);
          final idxB = order.indexOf(b['id']);
          if (idxA == -1 && idxB == -1) return 0;
          if (idxA == -1) return 1;
          if (idxB == -1) return -1;
          return idxA.compareTo(idxB);
        });
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _descCtrl,
      _detailCtrl,
      _priceCtrl,
      _compareCtrl,
      _costCtrl,
      _supplierPriceCtrl,
      _skuCtrl,
      _stockCtrl,
      _slugCtrl,
      _metaTitleCtrl,
      _metaDescCtrl,
      _minStockCtrl,
      _dialSizeCtrl,
      _dialColorCtrl,
      _caseColorCtrl,
      _caseCtrl,
      _strapMatCtrl,
      _strapColCtrl,
      _strapWidthCtrl,
      _movementCtrl,
      _glassCtrl,
      _waterCtrl,
      _hourMarkersCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final client = ApiClient(token: context.read<AuthProvider>().token);
      final data = await client.get(
        '${ApiConfig.authProductsEndpoint}/options',
      );
      if (mounted) {
        setState(() {
          _cats = data['categories'];
          _brands = data['brands'];
          _mats = data['materials'];
          _supps = data['suppliers'];
          _loadingOpts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOpts = false);
    }
  }

  Future<void> _pickImage(bool gallery) async {
    final token = context.read<AuthProvider>().token;
    final f = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (f == null) return;
    if (!gallery) {
      setState(() => _imageFile = File(f.path));
      return;
    }

    setState(() => _saving = true);
    try {
      final client = ApiClient(token: token);
      final res = await client.uploadMultipart(
        ApiConfig.uploadEndpoint,
        filePath: f.path,
        fileField: 'file',
        fields: {'folder': 'products/gallery'},
      );
      if (mounted) setState(() => _gallery.add(res['url']));
    } catch (e) {
      if (mounted) _snack('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      _snack('Please fill all required fields');
      return;
    }
    setState(() => _saving = true);
    try {
      final client = ApiClient(token: context.read<AuthProvider>().token);

      if (_imageFile != null) {
        final res = await client.uploadMultipart(
          ApiConfig.uploadEndpoint,
          filePath: _imageFile!.path,
          fileField: 'file',
          fields: {'folder': 'products'},
        );
        _imageUrl = res['url'];
      }

      final specs = <String, String>{};
      void addSpec(String k, TextEditingController c) {
        if (c.text.trim().isNotEmpty) specs[k] = c.text.trim();
      }

      addSpec('dialSize', _dialSizeCtrl);
      addSpec('dialColor', _dialColorCtrl);
      addSpec('caseColor', _caseColorCtrl);
      addSpec('case', _caseCtrl);
      addSpec('strapMaterial', _strapMatCtrl);
      addSpec('strapColor', _strapColCtrl);
      addSpec('strapWidth', _strapWidthCtrl);
      addSpec('movement', _movementCtrl);
      addSpec('glass', _glassCtrl);
      addSpec('waterResistance', _waterCtrl);
      addSpec('hourMarkers', _hourMarkersCtrl);
      addSpec('supplierPrice', _supplierPriceCtrl);
      addSpec('additionalCosts', _costCtrl);

      final body = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'status': _status,
        'price': double.tryParse(_priceCtrl.text) ?? 0,
        'sku': _skuCtrl.text.trim(),
        'gallery': _gallery,
        'showInNewArrivals': _newArrivals,
        'showInForYou': _forYou,
        'specs': specs,
        'similarProductIds': _relatedProducts.map((p) => p['id']).toList(),
        'orderedSimilarIds': _relatedProducts.map((p) => p['id']).toList(),
      };

      if (!_isEdit) {
        body['purchaseDate'] = _purchaseDate.toIso8601String();
      }

      void addOpt(String k, String v) {
        if (v.isNotEmpty) body[k] = v;
      }

      void addOptN(String k, String v) {
        if (v.isNotEmpty) body[k] = double.tryParse(v);
      }

      addOpt('description', _descCtrl.text.trim());
      addOpt('detailedDescription', _detailCtrl.text.trim());
      addOptN('compareAtPrice', _compareCtrl.text);
      addOpt('slug', _slugCtrl.text.trim());
      addOpt('metaTitle', _metaTitleCtrl.text.trim());
      addOpt('metaDescription', _metaDescCtrl.text.trim());

      if (_catId != null) body['categoryId'] = _catId;
      if (_brandId != null) body['brandId'] = _brandId;
      if (_matId != null) body['materialId'] = _matId;
      if (_suppId != null) body['supplierId'] = _suppId;
      if (_imageUrl != null) body['imageUrl'] = _imageUrl;

      if (_stockCtrl.text.isNotEmpty) {
        body['stock'] = int.tryParse(_stockCtrl.text);
      }
      if (_minStockCtrl.text.isNotEmpty) {
        body['minStock'] = int.tryParse(_minStockCtrl.text);
      }
      final supplierP = double.tryParse(_supplierPriceCtrl.text) ?? 0;
      final additionalC = double.tryParse(_costCtrl.text) ?? 0;
      if (supplierP + additionalC > 0) {
        body['costPrice'] = supplierP + additionalC;
      }

      if (widget.returnResult) {
        final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
        final tempVariantId = 'temp_var_${DateTime.now().millisecondsSinceEpoch}';
        
        final newProductMap = {
          'id': tempId,
          'name': _nameCtrl.text.trim(),
          'sku': _skuCtrl.text.trim(),
          'price': double.tryParse(_priceCtrl.text) ?? 0.0,
          'imageUrl': _imageUrl,
          'status': _status,
          'costPrice': supplierP + additionalC,
          'isDraftProduct': true,
          'productData': body,
          'variants': [
            {
              'id': tempVariantId,
              'sku': _skuCtrl.text.trim(),
              'price': double.tryParse(_priceCtrl.text) ?? 0.0,
              'costPrice': supplierP + additionalC,
            }
          ],
          'defaultVariantId': tempVariantId,
        };

        if (mounted) {
          _snack('Product drafted successfully', ok: true);
          Navigator.pop(context, newProductMap);
        }
        return;
      }

      if (_isEdit) {
        await client.put(
          '${ApiConfig.authProductsEndpoint}/${widget.product!['id']}',
          body: body,
        );
      } else {
        await client.post(ApiConfig.authProductsEndpoint, body: body);
      }

      if (mounted) {
        _snack(
          _isEdit
              ? 'Product updated successfully'
              : 'Product created successfully',
          ok: true,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _snack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m, {bool ok = false}) =>
      ScaffoldMessenger.of(context).showAppToast(
        AppToast.snackBar(
          content: Text(m, style: const TextStyle(color: Colors.white)),
          backgroundColor: ok ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

  // ── UI WIZARD PAGES ──

  Widget _buildStep0() {
    return _pageContainer(
      title: 'General & Organization',
      subtitle: 'Basic details and classification',
      icon: LucideIcons.box,
      children: [
        _buildSectionTitle('Basic Details', LucideIcons.info),
        _field('Product Name', _nameCtrl, req: true, icon: LucideIcons.tag),
        _field(
          'SKU (Stock Keeping Unit)',
          _skuCtrl,
          req: true,
          icon: LucideIcons.scanLine,
        ),
        _dropdown(
          'Status',
          LucideIcons.activity,
          [
            {'id': 'active', 'name': 'Active'},
            {'id': 'draft', 'name': 'Draft'},
            {'id': 'archived', 'name': 'Archived'},
          ],
          _status,
          (v) => setState(() => _status = v!),
        ),

        const SizedBox(height: 24),
        _buildSectionTitle('Organization', LucideIcons.layers),
        if (_loadingOpts)
          const Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppShimmer(
                      width: double.infinity,
                      height: 56,
                      borderRadius: 16,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: AppShimmer(
                      width: double.infinity,
                      height: 56,
                      borderRadius: 16,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppShimmer(
                      width: double.infinity,
                      height: 56,
                      borderRadius: 16,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: AppShimmer(
                      width: double.infinity,
                      height: 56,
                      borderRadius: 16,
                    ),
                  ),
                ],
              ),
            ],
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: _dropdown(
                  'Category',
                  LucideIcons.grid,
                  _cats,
                  _catId,
                  (v) => setState(() => _catId = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dropdown(
                  'Brand',
                  LucideIcons.award,
                  _brands,
                  _brandId,
                  (v) => setState(() => _brandId = v),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _dropdown(
                  'Material',
                  LucideIcons.layers,
                  _mats,
                  _matId,
                  (v) => setState(() => _matId = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dropdown(
                  'Supplier',
                  LucideIcons.truck,
                  _supps,
                  _suppId,
                  (v) => setState(() => _suppId = v),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStep1() {
    return _pageContainer(
      title: 'Pricing & Inventory',
      subtitle: 'Set your prices and initial stock',
      icon: LucideIcons.wallet,
      children: [
        Row(
          children: [
            Expanded(
              child: _field(
                'Price (EGP)',
                _priceCtrl,
                req: true,
                num: true,
                icon: LucideIcons.coins,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _field(
                'Compare At',
                _compareCtrl,
                num: true,
                icon: LucideIcons.trendingDown,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _field(
                'Additional Costs',
                _costCtrl,
                num: true,
                icon: LucideIcons.calculator,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _field(
                'Low Stock Alert Threshold',
                _minStockCtrl,
                num: true,
                icon: LucideIcons.alertTriangle,
                req: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.alertCircle,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Inventory & Wholesale',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _isEdit
                    ? 'Wholesale price is read-only. Stock can only be managed via stock adjustments.'
                    : 'Set the initial stock, wholesale purchase price, and purchase date for the first batch.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      'Wholesale (Purchase Price)',
                      _supplierPriceCtrl,
                      num: true,
                      req: !_isEdit,
                      readOnly: _isEdit,
                      icon: LucideIcons.tag,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      'Initial Stock',
                      _stockCtrl,
                      num: true,
                      req: !_isEdit,
                      readOnly: _isEdit,
                      icon: LucideIcons.packagePlus,
                    ),
                  ),
                ],
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _purchaseDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _purchaseDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.calendar,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            DateFormat('MMM dd, yyyy').format(_purchaseDate),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildProfitAnalysis(),
      ],
    );
  }

  Widget _buildProfitAnalysis() {
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final compareAt = double.tryParse(_compareCtrl.text) ?? 0;
    final wholesale = double.tryParse(_supplierPriceCtrl.text) ?? 0;
    final additionalCosts = double.tryParse(_costCtrl.text) ?? 0;
    final stock = int.tryParse(_stockCtrl.text) ?? 0;
    final totalCost = wholesale + additionalCosts;

    if (price <= 0 && totalCost <= 0) return const SizedBox.shrink();

    final profitPerUnit = price - totalCost;
    final marginPct = price > 0 ? (profitPerUnit / price) * 100 : 0.0;
    final markupPct = totalCost > 0 ? (profitPerUnit / totalCost) * 100 : 0.0;

    final hasDiscount = compareAt > 0 && compareAt > price;
    final discountAmount = hasDiscount ? compareAt - price : 0.0;
    final discountPct = hasDiscount ? (discountAmount / compareAt) * 100 : 0.0;
    final profitBeforeDiscount = hasDiscount ? compareAt - totalCost : 0.0;
    final marginBeforeDiscount = hasDiscount && compareAt > 0
        ? (profitBeforeDiscount / compareAt) * 100
        : 0.0;

    final totalProfit = profitPerUnit * stock;
    final totalRevenue = price * stock;
    final roiPct = (totalCost * stock) > 0
        ? (totalProfit / (totalCost * stock)) * 100
        : 0.0;

    final isProfit = profitPerUnit > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryDark.withValues(alpha: 0.05),
            AppColors.primaryDark.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryDark.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.barChart2,
                size: 16,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: 8),
              Text(
                'Profit Analysis',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total Cost Row
          _profitRow(
            'Total Cost',
            '${totalCost.toStringAsFixed(0)} EGP',
            AppColors.textSecondary,
            icon: LucideIcons.receipt,
          ),
          const Divider(height: 20),

          // Per Unit Profit
          _profitRow(
            'Profit / Unit',
            '${profitPerUnit.toStringAsFixed(0)} EGP',
            isProfit ? AppColors.success : AppColors.error,
            icon: isProfit ? LucideIcons.trendingUp : LucideIcons.trendingDown,
            bold: true,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _profitChip(
                  'Margin',
                  '${marginPct.toStringAsFixed(1)}%',
                  isProfit ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _profitChip(
                  'Markup',
                  '${markupPct.toStringAsFixed(1)}%',
                  AppColors.primaryDark,
                ),
              ),
            ],
          ),

          // Discount Section
          if (hasDiscount) ...[
            const Divider(height: 24),
            _profitRow(
              'Discount',
              '${discountAmount.toStringAsFixed(0)} EGP (${discountPct.toStringAsFixed(1)}%)',
              AppColors.warning,
              icon: LucideIcons.percent,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _profitChip(
                    'Before Discount',
                    '${profitBeforeDiscount.toStringAsFixed(0)} EGP',
                    AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _profitChip(
                    'Margin (Pre)',
                    '${marginBeforeDiscount.toStringAsFixed(1)}%',
                    AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],

          // Bulk Revenue Section
          if (stock > 0) ...[
            const Divider(height: 24),
            _profitRow(
              'Total Revenue',
              '${totalRevenue.toStringAsFixed(0)} EGP',
              AppColors.textPrimary,
              icon: LucideIcons.banknote,
            ),
            const SizedBox(height: 4),
            _profitRow(
              'Total Profit (×$stock)',
              '${totalProfit.toStringAsFixed(0)} EGP',
              isProfit ? AppColors.success : AppColors.error,
              icon: LucideIcons.piggyBank,
              bold: true,
            ),
            const SizedBox(height: 8),
            _profitChip(
              'ROI',
              '${roiPct.toStringAsFixed(1)}%',
              AppColors.primaryDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _profitRow(
    String label,
    String value,
    Color color, {
    IconData? icon,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _profitChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return _pageContainer(
      title: 'Media & Details',
      subtitle: 'Product images, description, and specifications',
      icon: LucideIcons.image,
      children: [
        _buildSectionTitle('Main Product Image', LucideIcons.image),
        GestureDetector(
          onTap: () => _pickImage(false),
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryDark.withValues(alpha: 0.3),
                style: BorderStyle.solid,
                width: 2,
              ),
            ),
            child: _imageFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(_imageFile!, fit: BoxFit.cover),
                  )
                : _imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                      cacheManager: AppImageCacheManager.instance,
                      imageUrl: _imageUrl!,
                      fit: BoxFit.cover,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.uploadCloud,
                        size: 32,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload Main Image',
                        style: GoogleFonts.inter(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 32),
        _buildSectionTitle('Gallery Images', LucideIcons.layoutGrid),
        _buildReorderableGallery(),

        const SizedBox(height: 32),
        _buildSectionTitle('Descriptions', LucideIcons.alignLeft),
        _field('Short Description', _descCtrl, lines: 3),
        _field('Detailed Description', _detailCtrl, lines: 5),

        const SizedBox(height: 24),
        _buildSectionTitle('Specifications', LucideIcons.list),
        Row(
          children: [
            Expanded(child: _field('Dial Size', _dialSizeCtrl)),
            const SizedBox(width: 12),
            Expanded(child: _field('Dial Color', _dialColorCtrl)),
          ],
        ),
        Row(
          children: [
            Expanded(child: _field('Case Material', _caseCtrl)),
            const SizedBox(width: 12),
            Expanded(child: _field('Case Color', _caseColorCtrl)),
          ],
        ),
        Row(
          children: [
            Expanded(child: _field('Strap Mat.', _strapMatCtrl)),
            const SizedBox(width: 12),
            Expanded(child: _field('Strap Color', _strapColCtrl)),
          ],
        ),
        Row(
          children: [
            Expanded(child: _field('Strap Width', _strapWidthCtrl)),
            const SizedBox(width: 12),
            Expanded(child: _field('Movement', _movementCtrl)),
          ],
        ),
        Row(
          children: [
            Expanded(child: _field('Glass', _glassCtrl)),
            const SizedBox(width: 12),
            Expanded(child: _field('Water Res.', _waterCtrl)),
          ],
        ),
        Row(
          children: [
            Expanded(child: _field('Hour Markers', _hourMarkersCtrl)),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildReorderableGallery() {
    return SizedBox(
      height: 90,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _pickImage(true),
            child: Container(
              width: 90,
              height: 90,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryDark.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(LucideIcons.plus, color: AppColors.primaryDark),
            ),
          ),
          Expanded(
            child: ReorderableListView(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: true,
              proxyDecorator: (child, index, animation) {
                return Material(
                  color: Colors.transparent,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                );
              },
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _gallery.removeAt(oldIndex);
                  _gallery.insert(newIndex, item);
                });
              },
              children: [
                for (int i = 0; i < _gallery.length; i++)
                  Container(
                    key: ValueKey(_gallery[i]),
                    width: 90,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            cacheManager: AppImageCacheManager.instance,
                            imageUrl: _gallery[i],
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => setState(() => _gallery.removeAt(i)),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.x,
                                size: 12,
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
        ],
      ),
    );
  }

  // ── UI HELPERS ──

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryDark),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return _pageContainer(
      title: 'SEO & Visibility',
      subtitle: 'Search engine settings and related products',
      icon: LucideIcons.search,
      children: [
        _buildSectionTitle('Related Products', LucideIcons.link2),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Drag and drop to reorder the items, or tap X to remove them.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _relatedProducts.removeAt(oldIndex);
                    _relatedProducts.insert(newIndex, item);
                  });
                },
                children: _relatedProducts
                    .map(
                      (p) => ReorderableDragStartListener(
                        key: ValueKey(p['id']),
                        index: _relatedProducts.indexOf(p),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.gripVertical,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  cacheManager: AppImageCacheManager.instance,
                                  imageUrl: p['image'],
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      Container(color: AppColors.cardBorder),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        color: AppColors.cardBorder,
                                        child: const Icon(
                                          LucideIcons.imageOff,
                                          size: 16,
                                        ),
                                      ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  p['name'],
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  LucideIcons.x,
                                  size: 16,
                                  color: AppColors.error,
                                ),
                                onPressed: () {
                                  setState(
                                    () => _relatedProducts.removeWhere(
                                      (element) => element['id'] == p['id'],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _showProductSelectionDialog,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add Related Product'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  side: const BorderSide(color: AppColors.primaryDark),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Visibility Options', LucideIcons.eye),
        Row(
          children: [
            Expanded(
              child: _switch(
                'New Arrivals',
                _newArrivals,
                (v) => setState(() => _newArrivals = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _switch(
                'For You',
                _forYou,
                (v) => setState(() => _forYou = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Search Engine Optimization', LucideIcons.search),
        _field('URL Slug', _slugCtrl, icon: LucideIcons.link),
        _field('Meta Title', _metaTitleCtrl),
        _field('Meta Description', _metaDescCtrl, lines: 3),
      ],
    );
  }

  Future<void> _showProductSelectionDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryDark),
      ),
    );
    try {
      final client = ApiClient(token: context.read<AuthProvider>().token);
      final data = await client.get(
        '${ApiConfig.authProductsEndpoint}?limit=200',
      );
      if (!mounted) return;
      Navigator.pop(context); // close loading dialog

      final products = data['products'] as List<dynamic>? ?? [];
      final availableProducts = products
          .where((p) => p['id'].toString() != widget.product?['id']?.toString())
          .toList();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          String searchQuery = '';
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final filtered = availableProducts.where((p) {
                final name = (p['name']?.toString() ?? '').toLowerCase();
                return name.contains(searchQuery.toLowerCase());
              }).toList();

              return AlertDialog(
                backgroundColor: AppColors.background,
                surfaceTintColor: AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(
                  'Select Related Products',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 400,
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search products...',
                          hintStyle: GoogleFonts.inter(
                            color: AppColors.textMuted,
                          ),
                          prefixIcon: const Icon(
                            LucideIcons.search,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 0,
                          ),
                        ),
                        onChanged: (val) =>
                            setDialogState(() => searchQuery = val),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final p = filtered[index];
                            final pid = p['id'].toString();
                            final isSelected = _relatedProducts.any(
                              (r) => r['id'] == pid,
                            );
                            final imgUrl =
                                p['imageUrl'] ??
                                (p['images']?.isNotEmpty == true
                                    ? p['images'][0]['url']
                                    : null);

                            return CheckboxListTile(
                              value: isSelected,
                              activeColor: AppColors.primaryDark,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                p['name']?.toString() ?? '',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              secondary: imgUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: CachedNetworkImage(
                                        cacheManager:
                                            AppImageCacheManager.instance,
                                        imageUrl: imgUrl.toString(),
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.cardBorder,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        LucideIcons.imageOff,
                                        size: 16,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _relatedProducts.add({
                                      'id': pid,
                                      'name': p['name']?.toString() ?? '',
                                      'image': imgUrl?.toString(),
                                    });
                                  } else {
                                    _relatedProducts.removeWhere(
                                      (r) => r['id'] == pid,
                                    );
                                  }
                                });
                                setDialogState(() {});
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Done',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // close loading dialog
      if (mounted) _snack('Failed to load products: $e');
    }
  }

  Widget _pageContainer({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primaryDark, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ...children,
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    bool req = false,
    bool num = false,
    int lines = 1,
    IconData? icon,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: c,
        keyboardType: num
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        maxLines: lines,
        readOnly: readOnly,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: readOnly ? AppColors.textMuted : AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
          prefixIcon: icon != null
              ? Icon(icon, size: 18, color: AppColors.textMuted)
              : null,
          filled: true,
          fillColor: readOnly
              ? AppColors.background.withValues(alpha: 0.5)
              : AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.primaryDark,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        validator: req && !readOnly
            ? (v) => (v == null || v.isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _dropdown(
    String label,
    IconData icon,
    List<dynamic> items,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: value,
        icon: const Icon(
          LucideIcons.chevronDown,
          size: 16,
          color: AppColors.textMuted,
        ),
        dropdownColor: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        elevation: 3,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        items: [
          DropdownMenuItem(
            value: null,
            child: Text(
              'None / Select',
              style: GoogleFonts.inter(color: AppColors.textMuted),
            ),
          ),
          ...items.map(
            (i) => DropdownMenuItem(
              value: i['id'].toString(),
              child: Text(i['name'].toString()),
            ),
          ),
        ],
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
          prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.primaryDark,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primaryDark,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          centerTitle: true,
          title: Text(
            _isEdit ? 'Edit Product' : 'New Product',
            style: GoogleFonts.playfairDisplay(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          leading: IconButton(
            icon: const Icon(LucideIcons.x, color: AppColors.primaryDark),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 20,
                ),
                color: AppColors.surface,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(_totalSteps * 2 - 1, (index) {
                    if (index.isEven) {
                      final stepIndex = index ~/ 2;
                      final isActive = stepIndex == _currentStep;
                      final isDone = stepIndex < _currentStep;

                      final icons = [
                        LucideIcons.box,
                        LucideIcons.wallet,
                        LucideIcons.image,
                        LucideIcons.search,
                      ];
                      final titles = ['General', 'Pricing', 'Media', 'SEO'];

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive
                                  ? AppColors.primaryDark
                                  : (isDone
                                        ? AppColors.success
                                        : AppColors.background),
                              border: Border.all(
                                color: isActive || isDone
                                    ? Colors.transparent
                                    : AppColors.cardBorder,
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              isDone ? LucideIcons.check : icons[stepIndex],
                              size: 16,
                              color: isActive || isDone
                                  ? Colors.white
                                  : AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            titles[stepIndex],
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isActive
                                  ? AppColors.primaryDark
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      );
                    } else {
                      final stepIndex = index ~/ 2;
                      final isDone = stepIndex < _currentStep;
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.only(
                            top: 16.5,
                            left: 8,
                            right: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDone
                                ? AppColors.success
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      );
                    }
                  }),
                ),
              ),

              // Content
              Expanded(
                child: IndexedStack(
                  index: _currentStep,
                  children: [
                    _buildStep0(),
                    _buildStep1(),
                    _buildStep2(),
                    _buildStep3(),
                  ],
                ),
              ),

              // Bottom Navigation
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() => _currentStep--);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                            side: const BorderSide(color: AppColors.cardBorder),
                          ),
                          child: Text(
                            'Back',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                            side: const BorderSide(color: AppColors.cardBorder),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _saving
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                if (_currentStep < _totalSteps - 1) {
                                  setState(() => _currentStep++);
                                } else {
                                  _save();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _currentStep < _totalSteps - 1
                                    ? 'Next Step'
                                    : (_isEdit
                                          ? 'Save Changes'
                                          : 'Create Product'),
                                style: GoogleFonts.inter(
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
      ),
    );
  }
}


