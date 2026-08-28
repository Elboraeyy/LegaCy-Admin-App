import 'package:admin_app/core/services/app_image_cache_manager.dart';
import 'package:admin_app/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:admin_app/core/constants/egypt_locations.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CreateManualOrderScreen extends StatefulWidget {
  final Map<String, dynamic>? existingOrder;
  const CreateManualOrderScreen({super.key, this.existingOrder});

  @override
  State<CreateManualOrderScreen> createState() =>
      _CreateManualOrderScreenState();
}

class _CreateManualOrderScreenState extends State<CreateManualOrderScreen> {
  void _onTextChanged() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onTextChanged);
    _phoneController.addListener(_onTextChanged);
    _addressController.addListener(_onTextChanged);
    if (widget.existingOrder != null) {
      final order = widget.existingOrder!;
      _nameController.text =
          order['displayName'] ?? order['customer']?['name'] ?? '';
      _phoneController.text =
          (order['phone'] ??
                  order['shippingPhone'] ??
                  order['customerPhone'] ??
                  order['phoneNumber'] ??
                  order['customer']?['phone'] ??
                  '')
              .toString();
      _alternativePhoneController.text =
          (order['alternativePhone'] ??
                  order['customer']?['alternativePhone'] ??
                  '')
              .toString();
      _emailController.text =
          (order['email'] ??
                  order['customerEmail'] ??
                  order['customer']?['email'] ??
                  '')
              .toString();

      final shippingAddr = order['shippingAddress'] ?? order['address'];
      if (shippingAddr != null) {
        if (shippingAddr is Map) {
          _addressController.text =
              (shippingAddr['street'] ??
                      shippingAddr['address'] ??
                      shippingAddr['addressLine1'] ??
                      '')
                  .toString();
          _selectedGovernorate =
              (shippingAddr['governorate'] ??
                      shippingAddr['state'] ??
                      order['shippingGovernorate'] ??
                      order['governorate'])
                  ?.toString();
          _selectedCity =
              (shippingAddr['city'] ??
                      shippingAddr['area'] ??
                      order['shippingCity'] ??
                      order['city'])
                  ?.toString();
        } else {
          _addressController.text = shippingAddr.toString();
          _selectedGovernorate =
              (order['shippingGovernorate'] ?? order['governorate'])
                  ?.toString();
          _selectedCity = (order['shippingCity'] ?? order['city'])?.toString();
        }
      } else {
        // Fallback to root level or customer level if shippingAddress is null
        _selectedGovernorate =
            (order['shippingGovernorate'] ??
                    order['governorate'] ??
                    order['customer']?['governorate'])
                ?.toString();
        _selectedCity =
            (order['shippingCity'] ??
                    order['city'] ??
                    order['customer']?['city'])
                ?.toString();
        _addressController.text =
            (order['address'] ?? order['customer']?['address'] ?? '')
                .toString();
      }

      _isExistingCustomer = true;
      _selectedCustomerId = order['customerId'];

      if (order['items'] != null) {
        _selectedItems.clear(); // Clear initial if any
        for (var item in order['items']) {
          _selectedItems.add({
            'productId': item['productId'],
            'variantId': item['variantId'],
            'quantity': item['quantity'],
            'imageUrl': item['imageUrl'] ?? item['product']?['imageUrl'],
            'name': item['name'] ?? item['productTitle'] ?? 'Product',
            'price': (item['price'] as num).toDouble(),
          });
        }
      }

      _shippingCost = (order['shippingCost'] as num? ?? 0).toDouble();
      _shippingController.text = _shippingCost.toStringAsFixed(0);
      _discountAmount = (order['discountAmount'] as num? ?? 0).toDouble();
      _discountController.text = _discountAmount.toStringAsFixed(0);
      _paymentMethod = order['paymentMethod'] ?? 'cod';
      _orderSource = order['source'] ?? order['orderSource'] ?? 'whatsapp';
      _orderNotesController.text = _displayOrderNotes(
        order['shippingNotes'] ?? order['customerNotes'] ?? order['orderNotes'],
      );
      if (order['createdAt'] != null) {
        _selectedOrderDate = DateTime.tryParse(order['createdAt']) ?? DateTime.now();
      }
    }
  }

  final _pageController = PageController();
  int _currentStep = 0;

  // Form Controllers - Customer
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _alternativePhoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _orderNotesController = TextEditingController();
  String? _selectedGovernorate;
  String? _selectedCity;

  bool _isExistingCustomer = false;
  final _customerSearchController = TextEditingController();
  String? _selectedCustomerId;

  // Selected Products
  final List<Map<String, dynamic>> _selectedItems = [];

  // Financials
  double _shippingCost = 0.0;
  String _shippingZoneName = '';
  bool _isLoadingShipping = false;
  final _shippingController = TextEditingController();
  double _discountAmount = 0.0;
  final _discountController = TextEditingController();
  String _paymentMethod = 'cod';
  String _orderSource = 'whatsapp';
  DateTime _selectedOrderDate = DateTime.now();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.removeListener(_onTextChanged);
    _phoneController.removeListener(_onTextChanged);
    _addressController.removeListener(_onTextChanged);
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _alternativePhoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _orderNotesController.dispose();
    _customerSearchController.dispose();
    _shippingController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  double get _subtotal {
    return _selectedItems.fold(
      0.0,
      (sum, item) => sum + (item['price'] * item['quantity']),
    );
  }

  double get _total {
    return _subtotal + _shippingCost - _discountAmount;
  }

  bool get _canProceed {
    if (_currentStep == 0) {
      return _nameController.text.trim().isNotEmpty &&
          _phoneController.text.trim().isNotEmpty &&
          _selectedGovernorate != null &&
          _addressController.text.trim().isNotEmpty;
    } else if (_currentStep == 1) {
      return _selectedItems.isNotEmpty;
    } else if (_currentStep == 2) {
      return !_isSubmitting &&
          _nameController.text.trim().isNotEmpty &&
          _phoneController.text.trim().isNotEmpty &&
          _selectedGovernorate != null &&
          _addressController.text.trim().isNotEmpty &&
          _selectedItems.isNotEmpty;
    }
    return false;
  }

  String _displayOrderNotes(dynamic value) {
    if (value == null) return '';

    String text = '';
    if (value is List) {
      text = value
          .map((e) => e is Map ? e['content']?.toString() ?? '' : e.toString())
          .where((e) => e.trim().isNotEmpty)
          .join(' - ');
    } else if (value is Map) {
      text = (value['content'] ?? value['text'] ?? value['note'] ?? '')
          .toString();
    } else {
      text = value.toString();
    }

    return text.replaceFirst(RegExp(r'^\\[[^\\]]+\\]\\s*'), '').trim();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // Validate Customer Step
      if (_nameController.text.trim().isEmpty ||
          _phoneController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showAppToast(
          AppToast.snackBar(
            content: Text('Please enter full name and phone number'),
          ),
        );
        return;
      }
      if (_selectedGovernorate == null ||
          _addressController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showAppToast(
          AppToast.snackBar(
            content: Text(
              'Please select a governorate and enter detailed address',
            ),
          ),
        );
        return;
      }
      // If city is required, we can check it, but let's stick to governorate and address for shipping minimums.
    } else if (_currentStep == 1) {
      // Validate Products Step
      if (_selectedItems.isEmpty) {
        ScaffoldMessenger.of(context).showAppToast(
          AppToast.snackBar(content: Text('Please add at least one product')),
        );
        return;
      }
    }

    if (_currentStep < 2) {
      HapticFeedback.lightImpact();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      HapticFeedback.lightImpact();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _selectOrderDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedOrderDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryDark,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      if (context.mounted) {
        final TimeOfDay? pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(_selectedOrderDate),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppColors.primaryDark,
                  onPrimary: Colors.white,
                  onSurface: AppColors.textPrimary,
                ),
              ),
              child: child!,
            );
          },
        );
        if (mounted) {
          setState(() {
            _selectedOrderDate = pickedTime != null
                ? DateTime(
                    picked.year,
                    picked.month,
                    picked.day,
                    pickedTime.hour,
                    pickedTime.minute,
                  )
                : picked;
          });
        }
      }
    }
  }

  Widget _orderDateSelector() {
    final dateStr = "${_selectedOrderDate.year}-${_selectedOrderDate.month.toString().padLeft(2, '0')}-${_selectedOrderDate.day.toString().padLeft(2, '0')} ${_selectedOrderDate.hour.toString().padLeft(2, '0')}:${_selectedOrderDate.minute.toString().padLeft(2, '0')}";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Date',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectOrderDate(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.calendar, size: 20, color: AppColors.primaryDark),
                    const SizedBox(width: 12),
                    Text(
                      dateStr,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.existingOrder != null
              ? 'Edit Order Details #${widget.existingOrder!['orderNumber'] ?? widget.existingOrder!['id'].toString().substring(0, 8)}'
              : 'Create Manual Order',
          style: GoogleFonts.playfairDisplay(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.x, color: AppColors.primaryDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            _buildStepIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentStep = i),
                children: [
                  _buildCustomerStep(),
                  _buildProductsStep(),
                  _buildSummaryStep(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _stepNode(0, 'Customer', LucideIcons.user),
          _stepLine(0),
          _stepNode(1, 'Products', LucideIcons.shoppingBag),
          _stepLine(1),
          _stepNode(2, 'Review', LucideIcons.checkCircle),
        ],
      ),
    );
  }

  Widget _stepNode(int index, String label, IconData icon) {
    bool isActive = _currentStep >= index;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryDark : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? AppColors.primaryDark : AppColors.divider,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive ? Colors.white : AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? AppColors.primaryDark : AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _stepLine(int index) {
    bool isActive = _currentStep > index;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16),
        color: isActive ? AppColors.primaryDark : AppColors.divider,
      ),
    );
  }

  Widget _buildCustomerStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.existingOrder == null) ...[
            Center(
              child: _sectionTitle('Customer Details'),
            ),
            const SizedBox(height: 16),
          ],
          _customerTypeToggle(),
          const SizedBox(height: 24),
          if (_isExistingCustomer) ...[
            _searchablePicker(
              'Search Existing Customer',
              _nameController.text.isEmpty ? null : _nameController.text,
              _showCustomerPicker,
            ),
            const SizedBox(height: 24),
          ],
          _textField(
            _nameController,
            'Full Name',
            LucideIcons.user,
            enabled: !_isExistingCustomer,
          ),
          const SizedBox(height: 16),
          _textField(
            _phoneController,
            'Phone Number',
            LucideIcons.phone,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _textField(
            _alternativePhoneController,
            'Alternative Phone (Optional)',
            LucideIcons.phoneCall,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _textField(
            _emailController,
            'Email (Optional)',
            LucideIcons.mail,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 24),
          _sectionTitle('Shipping Address'),
          const SizedBox(height: 20),
          _searchablePicker(
            'Governorate',
            _selectedGovernorate,
            () => _showLocationPicker('governorate'),
          ),
          const SizedBox(height: 16),
          _searchablePicker(
            'City / Area',
            _selectedCity,
            () => _showLocationPicker('city'),
            enabled: _selectedGovernorate != null,
          ),
          const SizedBox(height: 16),
          _textField(
            _addressController,
            'Detailed Address',
            LucideIcons.mapPin,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildProductsStep() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle('Selected Products'),
              OutlinedButton.icon(
                onPressed: _showProductPicker,
                icon: const Icon(LucideIcons.plus, size: 14, color: AppColors.primaryDark),
                label: Text(
                  'Add Product',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  side: const BorderSide(color: AppColors.primaryDark, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _selectedItems.isEmpty
              ? _buildEmptyProducts()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _selectedItems.length,
                  itemBuilder: (context, index) {
                    final item = _selectedItems[index];
                    return _productListItem(item, index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyProducts() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.shoppingCart,
            size: 64,
            color: AppColors.textMuted.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No products added yet',
            style: GoogleFonts.inter(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _showProductPicker,
            child: const Text('Search & Add Products'),
          ),
        ],
      ),
    );
  }

  Widget _productListItem(Map<String, dynamic> item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 50,
              height: 50,
              color: AppColors.shimmer,
              child: item['imageUrl'] != null
                  ? CachedNetworkImage(
                      cacheManager: AppImageCacheManager.instance,
                      imageUrl: item['imageUrl'],
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: AppColors.shimmer),
                      errorWidget: (context, url, error) =>
                          const Icon(LucideIcons.image, size: 20),
                    )
                  : const Icon(LucideIcons.image, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'],
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'SKU: ${item['sku']}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  _qtyBtn(LucideIcons.minus, () {
                    setState(() {
                      if (item['quantity'] > 1) {
                        item['quantity']--;
                      } else {
                        _selectedItems.removeAt(index);
                      }
                    });
                  }),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${item['quantity']}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _qtyBtn(LucideIcons.plus, () {
                    final maxStock = item['stockQuantity'] ?? 999;
                    if (item['quantity'] < maxStock) {
                      setState(() {
                        item['quantity']++;
                      });
                    } else {
                      ScaffoldMessenger.of(context).showAppToast(
                        AppToast.snackBar(
                          content: Text('Cannot exceed available stock'),
                        ),
                      );
                    }
                  }),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${(item['price'] * item['quantity']).toStringAsFixed(0)} EGP',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: AppColors.primaryDark),
      ),
    );
  }

  Widget _buildSummaryStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Order Summary'),
          const SizedBox(height: 20),
          _summaryCard(),
          const SizedBox(height: 24),
          _sectionTitle('Additional Details'),
          const SizedBox(height: 20),
          _sourceDropdown(),
          const SizedBox(height: 16),
          _paymentDropdown(),
          const SizedBox(height: 16),
          _orderDateSelector(),
          const SizedBox(height: 16),
          _textField(
            _orderNotesController,
            'Order Notes (Optional)',
            LucideIcons.fileText,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _financialInputs(),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _summaryRow(
            'Subtotal',
            '${_subtotal.toStringAsFixed(0)} EGP',
            Colors.white70,
          ),
          _summaryRow(
            _shippingZoneName.isNotEmpty
                ? 'Shipping ($_shippingZoneName)'
                : 'Shipping',
            _isLoadingShipping
                ? '...'
                : '${_shippingCost.toStringAsFixed(0)} EGP',
            Colors.white70,
          ),
          if (_discountAmount > 0)
            _summaryRow(
              'Discount',
              '-${_discountAmount.toStringAsFixed(0)} EGP',
              Colors.greenAccent,
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white12),
          ),
          _summaryRow(
            'Total Price',
            '${_total.toStringAsFixed(0)} EGP',
            Colors.white,
            isLarge: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value,
    Color color, {
    bool isLarge = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isLarge ? 16 : 13,
              color: color,
              fontWeight: isLarge ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isLarge ? 22 : 14,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _financialInputs() {
    return Row(
      children: [
        Expanded(
          child: _smallField(
            'Shipping',
            (v) => setState(() => _shippingCost = double.tryParse(v) ?? 0.0),
            controller: _shippingController,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _smallField(
            'Discount',
            (v) => setState(() => _discountAmount = double.tryParse(v) ?? 0.0),
            controller: _discountController,
          ),
        ),
      ],
    );
  }

  Widget _smallField(
    String label,
    Function(String) onChanged, {
    String? initial,
    TextEditingController? controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: controller != null ? null : initial,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
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
                onPressed: _prevStep,
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _canProceed
                  ? (_currentStep == 2 ? _submitOrder : _nextStep)
                  : null,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _currentStep == 2
                          ? (widget.existingOrder != null
                                ? 'Update Order'
                                : 'Create Order')
                          : 'Continue',
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.playfairDisplay(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.primaryDark,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _textField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: enabled ? AppColors.textPrimary : AppColors.textMuted,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
        fillColor: enabled ? Colors.white : AppColors.background,
      ),
    );
  }

  Widget _searchablePicker(
    String label,
    String? value,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value ?? label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: value != null
                    ? AppColors.textPrimary
                    : AppColors.textMuted,
              ),
            ),
            Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _showLocationPicker(String type) {
    List<String> options = [];
    if (type == 'governorate') {
      options = egyptLocations.map((g) => g.en).toList();
    } else {
      final gov = egyptLocations.firstWhere(
        (g) => g.en == _selectedGovernorate,
      );
      options = gov.cities.map((c) => c.en).toList();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LocationSearchSheet(
        title: 'Select $type',
        options: options,
        onSelect: (val) {
          setState(() {
            if (type == 'governorate') {
              _selectedGovernorate = val;
              _selectedCity = null; // Reset city when gov changes
            } else {
              _selectedCity = val;
            }
          });
          _updateShippingCost();
        },
      ),
    );
  }

  Future<void> _updateShippingCost() async {
    if (_selectedGovernorate == null) return;

    if (mounted) {
      setState(() => _isLoadingShipping = true);
    }

    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);

      // Build query with subtotal for free shipping threshold check
      final queryParams = {
        'governorate': _selectedGovernorate!,
        if (_selectedCity != null && _selectedCity!.isNotEmpty)
          'city': _selectedCity!,
        if (_subtotal > 0) 'subtotal': _subtotal.toString(),
      };
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final data = await client.get(
        '/api/admin/auth/orders/shipping-rate?$queryString',
      );

      if (!mounted) return;
      setState(() {
        _shippingCost = (data['rate'] as num).toDouble();
        _shippingZoneName = data['zoneName'] as String? ?? '';
        _isLoadingShipping = false;
        _shippingController.text = _shippingCost.toStringAsFixed(0);
      });
    } catch (e) {
      debugPrint('Shipping rate fetch error: $e');
      // Do NOT use hardcoded fallback — show error instead
      if (mounted) {
        setState(() {
          _isLoadingShipping = false;
        });
        ScaffoldMessenger.of(context).showAppToast(
          AppToast.snackBar(
            content: Text(
              'Could not fetch shipping rate from server. Please check connection.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _customerTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          _toggleBtn(
            'New Customer',
            !_isExistingCustomer,
            () => setState(() {
              _isExistingCustomer = false;
              _clearCustomerFields();
            }),
          ),
          _toggleBtn(
            'Existing',
            _isExistingCustomer,
            () => setState(() {
              _isExistingCustomer = true;
            }),
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryDark : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? Colors.white : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  void _clearCustomerFields() {
    _selectedCustomerId = null;
    _nameController.clear();
    _phoneController.clear();
    _alternativePhoneController.clear();
    _emailController.clear();
    _selectedGovernorate = null;
    _selectedCity = null;
    _addressController.clear();
    _orderNotesController.clear();
    _shippingCost = 0.0;
    _shippingZoneName = '';
    _shippingController.clear();
  }

  void _showCustomerPicker() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CustomerSearchSheet(
        onSelect: (customer) => _populateCustomerData(customer['id']),
      ),
    );
  }

  Future<void> _populateCustomerData(String id) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedCustomerId = id;
      _isSubmitting = true; // Show loading
    });

    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final data = await client.get('/api/admin/auth/customers/$id');

      if (mounted) {
        setState(() {
          _nameController.text = data['name'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _emailController.text = data['email'] ?? '';

          // Try to get address from last order
          if (data['orders'] != null && data['orders'].isNotEmpty) {
            final lastOrder = data['orders'][0];
            _selectedGovernorate = lastOrder['shippingGovernorate'];
            _selectedCity = lastOrder['shippingCity'];
            _addressController.text = lastOrder['shippingAddress'] ?? '';
          }
        });
        // Fetch shipping rate from server for the customer's location
        if (_selectedGovernorate != null) {
          _updateShippingCost();
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppToast(
          AppToast.snackBar(content: Text('Failed to fetch customer details')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _sourceDropdown() {
    return _selectableChips(
      label: 'Order Source',
      value: _orderSource,
      options: [
        {
          'id': 'whatsapp',
          'label': 'WhatsApp',
          'icon': LucideIcons.messageCircle,
        },
        {'id': 'facebook', 'label': 'Facebook', 'icon': Icons.facebook},
        {
          'id': 'instagram',
          'label': 'Instagram',
          'icon': Icons.camera_alt,
        },
        {'id': 'phone', 'label': 'Phone', 'icon': LucideIcons.phone},
        {'id': 'website', 'label': 'Website', 'icon': LucideIcons.globe},
        {'id': 'in-person', 'label': 'In Real', 'icon': LucideIcons.user},
      ],
      onChanged: (v) => setState(() => _orderSource = v),
    );
  }

  Widget _paymentDropdown() {
    return _selectableChips(
      label: 'Payment Method',
      value: _paymentMethod,
      options: [
        {'id': 'cod', 'label': 'COD', 'icon': LucideIcons.banknote},
        {'id': 'instapay', 'label': 'InstaPay', 'icon': LucideIcons.send},
        {'id': 'wallet', 'label': 'Wallet', 'icon': LucideIcons.wallet},
        {'id': 'card', 'label': 'Card', 'icon': LucideIcons.creditCard},
      ],
      onChanged: (v) => setState(() => _paymentMethod = v),
    );
  }

  Widget _selectableChips({
    required String label,
    required String value,
    required List<Map<String, dynamic>> options,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = value == opt['id'];
            return GestureDetector(
              onTap: () => onChanged(opt['id']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryDark : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryDark
                        : AppColors.cardBorder,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primaryDark.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      opt['icon'],
                      size: 16,
                      color: isSelected ? Colors.white : AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      opt['label'],
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showProductPicker() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProductPickerSheet(
        onAdd: (item) {
          setState(() {
            int idx = _selectedItems.indexWhere(
              (i) => i['variantId'] == item['variantId'],
            );
            if (idx != -1) {
              _selectedItems[idx]['quantity'] += item['quantity'];
            } else {
              _selectedItems.add(item);
            }
          });
          ScaffoldMessenger.of(context).showAppToast(
            AppToast.snackBar(
              content: Text('${item['name']} added to order'),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.success,
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitOrder() async {
    if (_nameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showAppToast(
        AppToast.snackBar(
          content: Text('Please fill required fields and add products'),
        ),
      );
      return;
    }
    if (_selectedGovernorate == null || _addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showAppToast(
        AppToast.snackBar(
          content: Text('Please select a governorate and enter an address'),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);

      final body = {
        'customer': _isExistingCustomer
            ? {'existingId': _selectedCustomerId}
            : {
                'name': _nameController.text,
                'phone': _phoneController.text,
                'alternativePhone': _alternativePhoneController.text.isEmpty
                    ? null
                    : _alternativePhoneController.text,
                'email': _emailController.text.isEmpty
                    ? null
                    : _emailController.text,
              },
        'shippingAddress': {
          'street': _addressController.text,
          'city': _selectedCity,
          'governorate': _selectedGovernorate,
        },
        'items': _selectedItems
            .map(
              (i) => {
                'productId': i['productId'],
                'variantId': i['variantId'],
                'quantity': i['quantity'],
                'imageUrl': i['imageUrl'],
              },
            )
            .toList(),
        'shippingCost': _shippingCost,
        'discountAmount': _discountAmount,
        'paymentMethod': _paymentMethod,
        'source': _orderSource,
        'notes': _orderNotesController.text.trim().isEmpty
            ? null
            : _orderNotesController.text.trim(),
        'createdAt': _selectedOrderDate.toIso8601String(),
      };

      if (widget.existingOrder != null) {
        await client.patch(
          '/api/admin/auth/orders/${widget.existingOrder!['id']}',
          body: body,
        );
      } else {
        await client.post('/api/admin/auth/orders', body: body);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showAppToast(
          AppToast.snackBar(
            content: Text(
              widget.existingOrder != null
                  ? 'Order updated successfully'
                  : 'Order created successfully',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppToast(
          AppToast.snackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _ProductPickerSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;
  const _ProductPickerSheet({required this.onAdd});

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _searchController = TextEditingController();
  List<dynamic> _results = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _search();
  }

  void _search() async {
    setState(() => _isSearching = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final data = await client.get(
        '/api/admin/auth/products?search=${Uri.encodeComponent(_searchController.text)}&hasStock=true&limit=1000',
      );
      setState(() => _results = data['products']);
    } catch (_) {
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              onChanged: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search products by name...',
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      'No results',
                      style: GoogleFonts.inter(color: AppColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final p = _results[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 56,
                            height: 56,
                            color: AppColors.shimmer,
                            child: p['imageUrl'] != null
                                ? CachedNetworkImage(
                                    cacheManager: AppImageCacheManager.instance,
                                    imageUrl: p['imageUrl'],
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        Container(color: AppColors.shimmer),
                                    errorWidget: (context, url, error) =>
                                        const Icon(LucideIcons.image),
                                  )
                                : const Icon(LucideIcons.image),
                          ),
                        ),
                        title: Text(
                          p['name'],
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${p['price']} EGP • SKU: ${p['sku'] ?? 'N/A'}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Add',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        onTap: () => _showQuantityAndVariantPicker(p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showQuantityAndVariantPicker(dynamic product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProductDetailSheet(
        product: product,
        onAdd: (item) {
          Navigator.of(context).pop(); // Close detail sheet
          widget.onAdd(item);
          // The parent pop will be handled by the user or here
          Navigator.of(context).pop(); // Close product search
        },
      ),
    );
  }
}

class _LocationSearchSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final Function(String) onSelect;

  const _LocationSearchSheet({
    required this.title,
    required this.options,
    required this.onSelect,
  });

  @override
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
  final _searchController = TextEditingController();
  List<String> _filteredOptions = [];

  @override
  void initState() {
    super.initState();
    _filteredOptions = widget.options;
  }

  void _filter(String query) {
    setState(() {
      _filteredOptions = widget.options
          .where((o) => o.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  autofocus: false,
                  onChanged: _filter,
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(LucideIcons.search, size: 20),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _filteredOptions.length,
              itemBuilder: (context, index) {
                final option = _filteredOptions[index];
                return ListTile(
                  title: Text(option, style: GoogleFonts.inter(fontSize: 14)),
                  onTap: () {
                    widget.onSelect(option);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerSearchSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onSelect;
  const _CustomerSearchSheet({required this.onSelect});

  @override
  State<_CustomerSearchSheet> createState() => _CustomerSearchSheetState();
}

class _CustomerSearchSheetState extends State<_CustomerSearchSheet> {
  final _searchController = TextEditingController();
  List<dynamic> _results = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _search();
  }

  void _search() async {
    setState(() => _isSearching = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final data = await client.get(
        '/api/admin/auth/customers/list?search=${Uri.encodeComponent(_searchController.text)}&limit=50',
      );
      setState(() => _results = data['data']);
    } catch (_) {
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Search Customers',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  autofocus: false,
                  onChanged: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: 'Search by name or phone...',
                    prefixIcon: const Icon(LucideIcons.search, size: 20),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      'No customers found',
                      style: GoogleFonts.inter(color: AppColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final c = _results[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryDark.withValues(
                            alpha: 0.1,
                          ),
                          child: Text(
                            c['name']?[0]?.toUpperCase() ?? '?',
                            style: GoogleFonts.inter(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          c['name'] ?? 'Guest',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          c['phone'] != null && c['phone'].toString().trim().isNotEmpty
                              ? '${c['phone']} • ${c['email'] ?? ''}'
                              : (c['email'] ?? ''),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        onTap: () {
                          widget.onSelect(c);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductDetailSheet extends StatefulWidget {
  final dynamic product;
  final Function(Map<String, dynamic>) onAdd;

  const _ProductDetailSheet({required this.product, required this.onAdd});

  @override
  State<_ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<_ProductDetailSheet> {
  int _quantity = 1;
  late dynamic _selectedVariant;

  @override
  void initState() {
    super.initState();
    final List<dynamic> variants = widget.product['variants'] ?? [];
    _selectedVariant = variants.isNotEmpty ? variants[0] : null;
  }

  int get _availableStock => _selectedVariant?['stockQuantity'] ?? 0;

  @override
  Widget build(BuildContext context) {
    final List<dynamic> variants = widget.product['variants'] ?? [];
    final bool outOfStock = _availableStock <= 0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 80,
                  height: 80,
                  color: AppColors.shimmer,
                  child: widget.product['imageUrl'] != null
                      ? CachedNetworkImage(
                          cacheManager: AppImageCacheManager.instance,
                          imageUrl: widget.product['imageUrl'],
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: AppColors.shimmer),
                          errorWidget: (context, url, error) =>
                              const Icon(LucideIcons.image),
                        )
                      : const Icon(LucideIcons.image),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product['name'],
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_selectedVariant?['price'] ?? widget.product['price']} EGP',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      outOfStock
                          ? 'Out of Stock'
                          : '$_availableStock Available',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: outOfStock ? AppColors.error : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (variants.length > 1) ...[
            Text(
              'Product SKU',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: variants.length,
                itemBuilder: (context, index) {
                  final v = variants[index];
                  final isSelected = _selectedVariant?['id'] == v['id'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedVariant = v;
                        _quantity = 1; // Reset quantity when variant changes
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryDark
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryDark
                              : AppColors.cardBorder,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        v['sku'],
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quantity',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.minus, size: 16),
                      onPressed: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                    ),
                    Text(
                      '$_quantity',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.plus, size: 16),
                      onPressed: _quantity < _availableStock
                          ? () => setState(() => _quantity++)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: outOfStock
                  ? null
                  : () {
                      try {
                        if (_selectedVariant == null) {
                          ScaffoldMessenger.of(context).showAppToast(
                            AppToast.snackBar(
                              content: Text('This product has no stock record yet'),
                            ),
                          );
                          return;
                        }

                        final item = {
                          'productId': widget.product['id'],
                          'variantId': _selectedVariant['id'],
                          'name': widget.product['name'],
                          'sku': _selectedVariant['sku'],
                          'price': double.parse(
                            (_selectedVariant['price'] ??
                                    widget.product['price'] ??
                                    0)
                                .toString(),
                          ),
                          'imageUrl': widget.product['imageUrl'],
                          'quantity': _quantity,
                          'stockQuantity': _availableStock,
                        };

                        widget.onAdd(item);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showAppToast(
                          AppToast.snackBar(
                            content: Text('Error adding product: $e'),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: outOfStock
                    ? AppColors.divider
                    : AppColors.primaryDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                outOfStock ? 'Out of Stock' : 'Add to Order',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: outOfStock ? AppColors.textMuted : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
