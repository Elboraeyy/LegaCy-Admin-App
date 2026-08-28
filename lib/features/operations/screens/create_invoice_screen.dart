import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:admin_app/core/widgets/app_toast.dart';
import 'package:intl/intl.dart';
import 'package:admin_app/features/products/add_product_screen.dart';
import 'package:admin_app/features/products/add_batch_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:admin_app/core/services/app_image_cache_manager.dart';

class InvoiceItemDraft {
  final Map<String, dynamic> product;
  final Map<String, dynamic>? variant;
  final int quantity;
  final double unitCost;
  final double? sellPrice;
  final double? expenses;
  final bool keepOldCost;
  final bool keepOldSellPrice;
  final bool keepOldExpenses;

  InvoiceItemDraft({
    required this.product,
    this.variant,
    required this.quantity,
    required this.unitCost,
    this.sellPrice,
    this.expenses,
    this.keepOldCost = true,
    this.keepOldSellPrice = true,
    this.keepOldExpenses = true,
  });

  Map<String, dynamic> toJson() {
    final isDraft = product['isDraftProduct'] == true;
    return {
      'productId': product['id'],
      'variantId': variant?['id'] ?? product['defaultVariantId'] ?? (product['variants'] != null && product['variants'].isNotEmpty ? product['variants'][0]['id'] : null),
      'quantity': quantity,
      'unitCost': unitCost,
      'sellPrice': sellPrice,
      'expenses': expenses,
      'keepOldCost': keepOldCost,
      'keepOldSellPrice': keepOldSellPrice,
      'keepOldExpenses': keepOldExpenses,
      'isDraftProduct': isDraft,
      'productData': isDraft ? product['productData'] : null,
    };
  }
}

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  int _currentStep = 0;
  final int _totalSteps = 3;
  final PageController _pageController = PageController();

  // Data lists
  List<dynamic> _suppliers = [];
  List<dynamic> _safes = [];
  bool _isLoadingData = true;
  bool _isSaving = false;

  // Step 1 variables
  final _numberCtrl = TextEditingController();
  DateTime _issueDate = DateTime.now();
  String? _selectedSupplierId;
  String _status = 'DRAFT';
  String? _selectedSafeId;

  // Step 2 variables
  final List<InvoiceItemDraft> _items = [];

  // Step 3 variables
  final _taxCtrl = TextEditingController(text: '0');
  final _shippingCtrl = TextEditingController(text: '0');
  final _discountCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  final _currencyFormat = NumberFormat('#,##0.00', 'en');

  @override
  void initState() {
    super.initState();
    _numberCtrl.text = 'INV-${DateTime.now().millisecondsSinceEpoch}';
    _fetchData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _numberCtrl.dispose();
    _taxCtrl.dispose();
    _shippingCtrl.dispose();
    _discountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);

      // Load suppliers
      final suppliersRes = await client.get('/api/admin/auth/procurement');
      // Load safes
      final safesRes = await client.get('/api/admin/auth/finance/safes');

      if (!mounted) return;
      setState(() {
        _suppliers = suppliersRes['suppliers'] as List<dynamic>? ?? [];
        _safes = safesRes['safes'] as List<dynamic>? ?? [];
        
        // Auto-select office safe if available
        if (_safes.isNotEmpty) {
          final firstSafe = _safes.first;
          _selectedSafeId = firstSafe['id']?.toString();
        }
        _isLoadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingData = false);
      _showToast('Failed to load metadata: $e', isError: true);
    }
  }



  void _nextStep() {
    if (_currentStep == 0) {
      if (_selectedSupplierId == null) {
        _showToast('Please select a supplier', isError: true);
        return;
      }
      if (_numberCtrl.text.trim().isEmpty) {
        _showToast('Please enter an invoice number', isError: true);
        return;
      }
      if (_status == 'POSTED' && _selectedSafeId == null) {
        _showToast('Deduction Safe is required to post the invoice', isError: true);
        return;
      }
    } else if (_currentStep == 1) {
      if (_items.isEmpty) {
        _showToast('Please add at least one product to the invoice', isError: true);
        return;
      }
    } else if (_currentStep == 2) {
      _saveInvoice();
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

  double get _subtotal {
    return _items.fold(0.0, (sum, item) => sum + (item.quantity * item.unitCost));
  }

  double get _grandTotal {
    final tax = double.tryParse(_taxCtrl.text) ?? 0.0;
    final shipping = double.tryParse(_shippingCtrl.text) ?? 0.0;
    final discount = double.tryParse(_discountCtrl.text) ?? 0.0;
    return (_subtotal + tax + shipping - discount).clamp(0.0, double.infinity);
  }

  Future<void> _saveInvoice() async {
    setState(() => _isSaving = true);
    try {
      final token = context.read<AuthProvider>().token;
      final adminId = context.read<AuthProvider>().user?['id'];
      final client = ApiClient(token: token);

      final body = {
        'invoiceNumber': _numberCtrl.text.trim(),
        'supplierId': _selectedSupplierId,
        'issueDate': _issueDate.toIso8601String(),
        'status': _status,
        'subtotal': _subtotal,
        'taxTotal': double.tryParse(_taxCtrl.text) ?? 0.0,
        'shippingTotal': double.tryParse(_shippingCtrl.text) ?? 0.0,
        'discountTotal': double.tryParse(_discountCtrl.text) ?? 0.0,
        'grandTotal': _grandTotal,
        'notes': _notesCtrl.text.trim(),
        'safeId': _status == 'POSTED' ? _selectedSafeId : null,
        'adminId': adminId,
        'items': _items.map((item) => item.toJson()).toList(),
      };

      await client.post('/api/admin/auth/procurement/invoices', body: body);

      if (!mounted) return;
      _showToast('Invoice created successfully!', isError: false);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showToast('Failed to save invoice: $e', isError: true);
    }
  }

  void _showToast(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showAppToast(
      AppToast.snackBar(
        content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
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
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: AppColors.primaryDark),
            onPressed: _prevStep,
          ),
          title: Text(
            'New Purchase Invoice',
            style: GoogleFonts.playfairDisplay(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / _totalSteps,
              backgroundColor: AppColors.cardBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
          ),
        ),
        body: _isLoadingData
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryDark))
            : Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildStep1Info(),
                        _buildStep2Items(),
                        _buildStep3Summary(),
                      ],
                    ),
                  ),
                  _buildBottomBar(),
                ],
              ),
      ),
    );
  }

  Widget _buildStep1Info() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(LucideIcons.building, color: Color(0xFF8B5CF6)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invoice Metadata', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                    Text('Specify supplier, invoice number and status', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Supplier Dropdown
          Text('Supplier', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                icon: const Icon(LucideIcons.chevronDown, color: AppColors.textMuted, size: 20),
                dropdownColor: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                hint: Text('Select Supplier', style: GoogleFonts.inter(color: AppColors.textMuted)),
                value: _selectedSupplierId,
                items: _suppliers.map<DropdownMenuItem<String>>((s) {
                  return DropdownMenuItem(
                    value: s['id'].toString(),
                    child: Text(s['name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedSupplierId = val),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Invoice Number
          Text('Invoice Number', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: _numberCtrl,
            decoration: InputDecoration(
              hintText: 'e.g. INV-100492',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.cardBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.cardBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2)),
              prefixIcon: const Icon(LucideIcons.hash, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 20),

          // Issue Date
          Text('Issue Date', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _issueDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) setState(() => _issueDate = date);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
              child: Row(
                children: [
                  const Icon(LucideIcons.calendar, color: AppColors.textMuted, size: 20),
                  const SizedBox(width: 12),
                  Text(DateFormat('MMM dd, yyyy').format(_issueDate), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Status & Safe
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          dropdownColor: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          value: _status,
                          items: ['DRAFT', 'POSTED'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.inter(fontWeight: FontWeight.w600)))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _status = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_status == 'POSTED') ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Deduct from Safe', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            dropdownColor: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            hint: Text('Select Safe', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                            value: _selectedSafeId,
                            items: _safes.map((s) => DropdownMenuItem(value: s['id']?.toString(), child: Text(s['name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (val) => setState(() => _selectedSafeId = val),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (_status == 'POSTED') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.error.withValues(alpha: 0.1))),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertTriangle, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'POSTED invoices deduct funds from the selected Safe immediately and update the products inventory count. This action is final.',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep2Items() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(LucideIcons.package, color: Color(0xFF8B5CF6)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invoice Items', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                    Text('Add products or new batches to this bill', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.shoppingCart, size: 64, color: AppColors.textMuted.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('No items added yet', style: GoogleFonts.inter(fontSize: 15, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                      Text('Add existing batches or create new products below', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final item = _items[i];
                    final double totalItemCost = item.quantity * item.unitCost;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                border: Border.all(color: AppColors.cardBorder, width: 1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: item.product['imageUrl'] != null && item.product['imageUrl'].toString().isNotEmpty
                                  ? CachedNetworkImage(
                                      cacheManager: AppImageCacheManager.instance,
                                      imageUrl: item.product['imageUrl'],
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: AppColors.background,
                                      ),
                                      errorWidget: (context, url, error) => const Center(
                                        child: Icon(
                                          LucideIcons.package,
                                          size: 20,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    )
                                  : const Center(
                                      child: Icon(
                                        LucideIcons.package,
                                        size: 20,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.product['name'] ?? 'Product', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.primaryDark, fontSize: 14)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text('Qty: ${item.quantity}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                                    const SizedBox(width: 12),
                                    Text('Cost: EGP ${item.unitCost}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                                  ],
                                ),
                                if (!item.keepOldSellPrice) ...[
                                  const SizedBox(height: 2),
                                  Text('New Sell Price: EGP ${item.sellPrice}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8B5CF6), fontWeight: FontWeight.w600)),
                                ],
                              ],
                            ),
                          ),
                          Text('EGP ${_currencyFormat.format(totalItemCost)}', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                          IconButton(
                            icon: const Icon(LucideIcons.trash2, color: AppColors.error, size: 18),
                            onPressed: () => setState(() => _items.removeAt(i)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(LucideIcons.plus, size: 16, color: Colors.white),
                  label: const Text('Add Batch'),
                  onPressed: _showAddBatchSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.plusCircle, size: 16, color: Color(0xFF8B5CF6)),
                  label: const Text('New Product'),
                  onPressed: _createNewProductFlow,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B5CF6),
                    side: const BorderSide(color: Color(0xFF8B5CF6)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3Summary() {
    Map<String, dynamic>? selectedSupplier;
    for (var s in _suppliers) {
      if (s['id']?.toString() == _selectedSupplierId) {
        selectedSupplier = s;
        break;
      }
    }
    final supplierName = selectedSupplier?['name'] ?? 'Unknown Supplier';

    Map<String, dynamic>? selectedSafe;
    for (var s in _safes) {
      if (s['id']?.toString() == _selectedSafeId) {
        selectedSafe = s;
        break;
      }
    }
    final safeName = selectedSafe?['name'] ?? 'Unknown Safe';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.clipboardCheck, color: Color(0xFF8B5CF6)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Review & Confirm', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                    Text('Double-check invoice details and items', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Metadata Card
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
                Text('General Information', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                _reviewRow('Supplier', supplierName),
                const SizedBox(height: 8),
                _reviewRow('Invoice Number', _numberCtrl.text.trim()),
                const SizedBox(height: 8),
                _reviewRow('Issue Date', DateFormat('MMM dd, yyyy').format(_issueDate)),
                const SizedBox(height: 8),
                _reviewRow('Status', _status),
                if (_status == 'POSTED') ...[
                  const SizedBox(height: 8),
                  _reviewRow('Deduct From Safe', safeName),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Items Summary Card
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Items List', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                    Text('${_items.length} items', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  itemBuilder: (context, idx) {
                    final item = _items[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product['name'] ?? '',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Qty: ${item.quantity} x EGP ${_currencyFormat.format(item.unitCost)}',
                                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'EGP ${_currencyFormat.format(item.quantity * item.unitCost)}',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Notes
          Text('Notes / Comments', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Enter purchase terms or details...',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.cardBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.cardBorder)),
            ),
          ),
          const SizedBox(height: 20),

          // Grand Total Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF12403C).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF12403C).withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Grand Total (Fully Paid)',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                ),
                Text(
                  'EGP ${_currencyFormat.format(_subtotal)}',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF8B5CF6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildBottomBar() {
    final isLast = _currentStep == _totalSteps - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            OutlinedButton(
              onPressed: _prevStep,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.cardBorder),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                shape: const StadiumBorder(),
              ),
              child: Text('Back', style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      isLast ? 'Finish & Save' : 'Next Step',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddBatchSheet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddBatchScreen(
          returnResult: true,
          supplierId: _selectedSupplierId,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      final product = result['product'] as Map<String, dynamic>;
      final qty = result['quantity'] as int;
      final cost = (result['newCost'] as double?) ?? (product['costPrice'] as num?)?.toDouble() ?? 0.0;
      
      setState(() {
        _items.add(
          InvoiceItemDraft(
            product: product,
            quantity: qty,
            unitCost: cost,
            keepOldCost: result['keepOldCost'] as bool? ?? true,
            keepOldSellPrice: result['keepOldSellPrice'] as bool? ?? true,
            keepOldExpenses: result['keepOldExpenses'] as bool? ?? true,
            sellPrice: result['newSellPrice'] as double?,
            expenses: result['newExpenses'] as double?,
          ),
        );
      });
    }
  }

  Future<void> _createNewProductFlow() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddProductScreen(returnResult: true),
      ),
    );
    if (result != null && result is Map<String, dynamic>) {
      _showAddBatchSheetForProduct(result);
    }
  }

  void _showAddBatchSheetForProduct(Map<String, dynamic> product) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddBatchScreen(
          returnResult: true,
          supplierId: _selectedSupplierId,
          initialProduct: product,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      final qty = result['quantity'] as int;
      final cost = (result['newCost'] as double?) ?? (product['costPrice'] as num?)?.toDouble() ?? 0.0;
      
      setState(() {
        _items.add(
          InvoiceItemDraft(
            product: product,
            quantity: qty,
            unitCost: cost,
            keepOldCost: result['keepOldCost'] as bool? ?? true,
            keepOldSellPrice: result['keepOldSellPrice'] as bool? ?? true,
            keepOldExpenses: result['keepOldExpenses'] as bool? ?? true,
            sellPrice: result['newSellPrice'] as double?,
            expenses: result['newExpenses'] as double?,
          ),
        );
      });
    }
  }
}
