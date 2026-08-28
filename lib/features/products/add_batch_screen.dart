import 'package:admin_app/core/services/app_image_cache_manager.dart';
import 'package:admin_app/core/widgets/app_toast.dart';
// ignore_for_file: deprecated_member_use
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
import 'package:intl/intl.dart';
import '../../core/widgets/app_shimmer.dart';

class AddBatchScreen extends StatefulWidget {
  final Map<String, dynamic>? initialProduct;
  final bool returnResult;
  final String? supplierId;

  const AddBatchScreen({
    super.key,
    this.initialProduct,
    this.returnResult = false,
    this.supplierId,
  });

  @override
  State<AddBatchScreen> createState() => _AddBatchScreenState();
}

class _AddBatchScreenState extends State<AddBatchScreen> {
  int _currentStep = 0;
  final int _totalSteps = 3;
  final PageController _pageController = PageController();

  List<dynamic> _products = [];
  List<dynamic> _suppliers = [];
  bool _isLoadingData = true;
  bool _isSaving = false;

  Map<String, dynamic>? _selectedProduct;
  final _quantityCtrl = TextEditingController();

  DateTime _purchaseDate = DateTime.now();
  String? _selectedSupplierId;

  bool _keepOldCost = true;
  final _newCostCtrl = TextEditingController();

  bool _keepOldSellPrice = true;
  final _newSellPriceCtrl = TextEditingController();

  bool _keepOldExpenses = true;
  final _newExpensesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialProduct != null) {
      _selectedProduct = widget.initialProduct;
    }
    if (widget.supplierId != null) {
      _selectedSupplierId = widget.supplierId;
    }
    _fetchData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _quantityCtrl.dispose();
    _newCostCtrl.dispose();
    _newSellPriceCtrl.dispose();
    _newExpensesCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final client = ApiClient(token: context.read<AuthProvider>().token);
      final productsRes = await client.get(
        '${ApiConfig.authProductsEndpoint}?limit=200',
      );
      final optionsRes = await client.get(
        '${ApiConfig.authProductsEndpoint}/options',
      );

      if (!mounted) return;
      setState(() {
        _products = productsRes['products'] as List<dynamic>? ?? [];
        _suppliers = optionsRes['suppliers'] ?? [];
        _isLoadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingData = false);
      _showSnack('Failed to load data: $e');
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_selectedProduct == null) {
        return _showSnack('Please select a product');
      }
      if (int.tryParse(_quantityCtrl.text) == null ||
          int.parse(_quantityCtrl.text) <= 0) {
        return _showSnack('Please enter a valid quantity');
      }
    } else if (_currentStep == 1) {
      if (_selectedSupplierId == null) {
        return _showSnack('Please select a supplier');
      }
    } else if (_currentStep == 2) {
      if (!_keepOldCost && double.tryParse(_newCostCtrl.text) == null) {
        return _showSnack('Invalid cost price');
      }
      if (!_keepOldSellPrice &&
          double.tryParse(_newSellPriceCtrl.text) == null) {
        return _showSnack('Invalid sell price');
      }
      if (!_keepOldExpenses && double.tryParse(_newExpensesCtrl.text) == null) {
        return _showSnack('Invalid expenses');
      }
      _saveBatch();
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _currentStep++);
    _pageController.animateToPage(
      _currentStep,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _prevStep() {
    if (_currentStep == 0) {
      Navigator.pop(context);
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _currentStep--);
    _pageController.animateToPage(
      _currentStep,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _saveBatch() async {
    setState(() => _isSaving = true);
    try {
      final client = ApiClient(token: context.read<AuthProvider>().token);

      final productId = _selectedProduct!['id'];
      final variantId =
          _selectedProduct!['defaultVariantId'] ??
          _selectedProduct!['variants']?[0]?['id'];

      final body = {
        'productId': productId,
        'variantId': variantId,
        'quantity': int.parse(_quantityCtrl.text),
        'purchaseDate': _purchaseDate.toIso8601String(),
        'supplierId': _selectedSupplierId,
        'keepOldCost': _keepOldCost,
        'newCost': _keepOldCost ? null : double.tryParse(_newCostCtrl.text),
        'keepOldSellPrice': _keepOldSellPrice,
        'newSellPrice': _keepOldSellPrice
            ? null
            : double.tryParse(_newSellPriceCtrl.text),
        'keepOldExpenses': _keepOldExpenses,
        'newExpenses': _keepOldExpenses
            ? null
            : double.tryParse(_newExpensesCtrl.text),
      };

      if (widget.returnResult) {
        body['product'] = _selectedProduct;
        Navigator.pop(context, body);
        return;
      }

      final response = await client.post('/api/admin/inventory/batches', body: body);

      if (!mounted) return;
      _showSnack(
        'Added ${response['quantityAdded'] ?? _quantityCtrl.text} units successfully',
        isSuccess: true,
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack('Failed to save batch: $e');
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showAppToast(
      AppToast.snackBar(
        content: Text(
          msg,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isSuccess ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  num _readNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }

  num _readAdditionalCosts(Map<String, dynamic>? product) {
    return _readNum(product?['specs']?['additionalCosts']);
  }

  num _readBasePurchasePrice(Map<String, dynamic>? product) {
    final supplierPrice = product?['specs']?['supplierPrice'];
    if (supplierPrice != null && supplierPrice.toString().trim().isNotEmpty) {
      return _readNum(supplierPrice);
    }

    final variants = product?['variants'] as List<dynamic>? ?? [];
    final storedCost = variants.isNotEmpty
        ? _readNum(variants[0]['costPrice'])
        : _readNum(product?['costPrice']);
    final baseCost = storedCost - _readAdditionalCosts(product);

    return baseCost > 0 ? baseCost : storedCost;
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
          leading: IconButton(
            icon: const Icon(
              LucideIcons.arrowLeft,
              color: AppColors.primaryDark,
            ),
            onPressed: _prevStep,
          ),
          title: Text(
            'New Product Batch',
            style: GoogleFonts.playfairDisplay(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / _totalSteps,
              backgroundColor: AppColors.cardBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryDark,
              ),
            ),
          ),
        ),
        body: _isLoadingData
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const AppShimmer(
                          width: 48,
                          height: 48,
                          shape: BoxShape.circle,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              AppShimmer(width: 150, height: 20),
                              SizedBox(height: 8),
                              AppShimmer(width: 250, height: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const AppShimmer(width: 120, height: 16),
                    const SizedBox(height: 8),
                    const AppShimmer(
                      width: double.infinity,
                      height: 56,
                      borderRadius: 16,
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [_buildStep1(), _buildStep2(), _buildStep3()],
                    ),
                  ),
                  _buildBottomBar(),
                ],
              ),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.package, color: AppColors.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Product',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Text(
                      'Choose the product to add stock to',
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
          const SizedBox(height: 32),

          Text(
            'Search Product',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _buildProductDropdown(),

          if (_selectedProduct != null) ...[
            const SizedBox(height: 32),
            Text(
              'New Quantity',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _quantityCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: 'e.g. 50',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.accent,
                    width: 2,
                  ),
                ),
                prefixIcon: const Icon(
                  LucideIcons.boxes,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductDropdown() {
    return InkWell(
      onTap: () => _showProductSelectionSheet(),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: _selectedProduct == null
                  ? Text(
                      'Select a product...',
                      style: GoogleFonts.inter(color: AppColors.textMuted),
                    )
                  : Text(
                      _selectedProduct!['name'] ?? '',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
            ),
            const Icon(LucideIcons.chevronDown, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _showProductSelectionSheet() {
    String search = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final filtered = _products
              .where(
                (p) => p['name'].toString().toLowerCase().contains(
                  search.toLowerCase(),
                ),
              )
              .toList();
          return FractionallySizedBox(
            heightFactor: 0.8,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: const Icon(LucideIcons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (val) => setSheetState(() => search = val),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final p = filtered[i];
                      return ListTile(
                        leading: p['imageUrl'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  cacheManager: AppImageCacheManager.instance,
                                  imageUrl: p['imageUrl'],
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(LucideIcons.imageOff),
                        title: Text(
                          p['name'] ?? '',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${p['price'] ?? 0} EGP',
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        onTap: () {
                          setState(() => _selectedProduct = p);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.truck, color: AppColors.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purchase Details',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Text(
                      'Enter supplier and date',
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
          const SizedBox(height: 32),

          Text(
            'Purchase Date',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _purchaseDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) setState(() => _purchaseDate = date);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.calendar,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('MMM dd, yyyy').format(_purchaseDate),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Supplier',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                icon: const Icon(
                  LucideIcons.chevronDown,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                dropdownColor: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                elevation: 4,
                hint: Row(
                  children: [
                    const Icon(
                      LucideIcons.user,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Select Supplier',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                value: _selectedSupplierId,
                items: _suppliers
                    .map<DropdownMenuItem<String>>(
                      (s) => DropdownMenuItem(
                        value: s['id'].toString(),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryDark.withValues(
                                  alpha: 0.1,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.user,
                                size: 14,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              s['name'] ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedSupplierId = val),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    final oldCost = _readBasePurchasePrice(_selectedProduct);
    final oldPrice = _selectedProduct?['price'] ?? 0;
    final oldExpenses = _readAdditionalCosts(_selectedProduct);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.banknote,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Pricing Rules',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Text(
                      'Set prices for this specific batch',
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
          const SizedBox(height: 24),

          _buildPricingToggle(
            title: 'Purchase Price (Cost)',
            oldValue: oldCost.toString(),
            keepOld: _keepOldCost,
            onChanged: (val) => setState(() => _keepOldCost = val),
            controller: _newCostCtrl,
          ),
          const SizedBox(height: 16),

          _buildPricingToggle(
            title: 'Selling Price',
            oldValue: oldPrice.toString(),
            keepOld: _keepOldSellPrice,
            onChanged: (val) => setState(() => _keepOldSellPrice = val),
            controller: _newSellPriceCtrl,
          ),
          const SizedBox(height: 16),

          _buildPricingToggle(
            title: 'Product Expenses',
            oldValue: oldExpenses.toString(),
            keepOld: _keepOldExpenses,
            onChanged: (val) => setState(() => _keepOldExpenses = val),
            controller: _newExpensesCtrl,
          ),

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryDark.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.info, color: AppColors.primaryDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'If you set new prices, the system will continue selling the old batch at old prices until it runs out. Then it will automatically switch to the new prices.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.primaryDark,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingToggle({
    required String title,
    required String oldValue,
    required bool keepOld,
    required ValueChanged<bool> onChanged,
    required TextEditingController controller,
  }) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
                ),
              ),
              Text(
                'Old: $oldValue EGP',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onChanged(true),
                  child: Row(
                    children: [
                      Radio<bool>(
                        value: true,
                        groupValue: keepOld,
                        activeColor: AppColors.primaryDark,
                        onChanged: (v) => onChanged(true),
                      ),
                      Text(
                        'Same as old',
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => onChanged(false),
                  child: Row(
                    children: [
                      Radio<bool>(
                        value: false,
                        groupValue: keepOld,
                        activeColor: AppColors.primaryDark,
                        onChanged: (v) => onChanged(false),
                      ),
                      Text('Set new', style: GoogleFonts.inter(fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (!keepOld) ...[
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                hintText: 'Enter new $title',
                filled: true,
                fillColor: AppColors.background,
                prefixText: 'EGP ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
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
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _prevStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppColors.cardBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    'Back',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _currentStep == _totalSteps - 1
                            ? 'Add New Batch'
                            : 'Continue',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


