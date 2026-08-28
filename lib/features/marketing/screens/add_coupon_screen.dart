import 'package:admin_app/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
// Keep for haptic if needed, though removed in other file
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/auth/auth_provider.dart';

class AddCouponScreen extends StatefulWidget {
  final Map<String, dynamic>? coupon;
  final String? defaultType;
  const AddCouponScreen({super.key, this.coupon, this.defaultType});

  @override
  State<AddCouponScreen> createState() => _AddCouponScreenState();
}

class _AddCouponScreenState extends State<AddCouponScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _codeCtrl;
  late TextEditingController _valueCtrl;
  late TextEditingController _minOrderCtrl;
  late TextEditingController _maxDiscountCtrl;
  late TextEditingController _usageLimitCtrl;

  String _discountType = 'percentage';
  bool _isActive = true;
  DateTime? _startDate;
  DateTime? _endDate;

  // Original state tracking
  String _origCode = '';
  String _origValue = '';
  String _origMinOrder = '';
  String _origMaxDiscount = '';
  String _origUsageLimit = '';
  String _origDiscountType = 'percentage';
  bool _origIsActive = true;
  DateTime? _origStartDate;
  DateTime? _origEndDate;

  bool get _hasChanges {
    if (widget.coupon == null) {
      return _codeCtrl.text.isNotEmpty; // For creation, any code implies a change
    }
    return _codeCtrl.text != _origCode ||
           _valueCtrl.text != _origValue ||
           _minOrderCtrl.text != _origMinOrder ||
           _maxDiscountCtrl.text != _origMaxDiscount ||
           _usageLimitCtrl.text != _origUsageLimit ||
           _discountType != _origDiscountType ||
           _isActive != _origIsActive ||
           _startDate != _origStartDate ||
           _endDate != _origEndDate;
  }

  @override
  void initState() {
    super.initState();
    final c = widget.coupon;
    _codeCtrl = TextEditingController(text: c?['code'] ?? '');
    _valueCtrl = TextEditingController(text: c?['discountValue']?.toString() ?? '');
    _minOrderCtrl = TextEditingController(text: c?['minOrderValue']?.toString() ?? '');
    _maxDiscountCtrl = TextEditingController(text: c?['maxDiscount']?.toString() ?? '');
    _usageLimitCtrl = TextEditingController(text: c?['usageLimit']?.toString() ?? '');

    _discountType = c?['discountType'] ?? widget.defaultType ?? 'percentage';
    _isActive = c?['isActive'] ?? true;
    _startDate = c?['startDate'] != null ? DateTime.tryParse(c!['startDate'])?.toLocal() : DateTime.now();
    _endDate = c?['endDate'] != null ? DateTime.tryParse(c!['endDate'])?.toLocal() : null;

    _origCode = _codeCtrl.text;
    _origValue = _valueCtrl.text;
    _origMinOrder = _minOrderCtrl.text;
    _origMaxDiscount = _maxDiscountCtrl.text;
    _origUsageLimit = _usageLimitCtrl.text;
    _origDiscountType = _discountType;
    _origIsActive = _isActive;
    _origStartDate = _startDate;
    _origEndDate = _endDate;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _valueCtrl.dispose();
    _minOrderCtrl.dispose();
    _maxDiscountCtrl.dispose();
    _usageLimitCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final initial = isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now().add(const Duration(days: 7)));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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

    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);

      final body = {
        'code': _codeCtrl.text.trim().toUpperCase(),
        'discountType': _discountType,
        'discountValue': _discountType == 'FREE_SHIPPING' ? 0.0 : double.parse(_valueCtrl.text),
        'isActive': _isActive,
        'startDate': _startDate?.toUtc().toIso8601String(),
        'endDate': _endDate?.toUtc().toIso8601String(),
      };

      if (_minOrderCtrl.text.isNotEmpty) {
        body['minOrderValue'] = double.parse(_minOrderCtrl.text);
      } else {
        body['minOrderValue'] = null;
      }

      if (_maxDiscountCtrl.text.isNotEmpty) {
        body['maxDiscount'] = double.parse(_maxDiscountCtrl.text);
      } else {
        body['maxDiscount'] = null;
      }

      if (_usageLimitCtrl.text.isNotEmpty) {
        body['usageLimit'] = int.parse(_usageLimitCtrl.text);
      } else {
        body['usageLimit'] = null;
      }

      if (widget.coupon != null) {
        await client.put('/api/admin/auth/coupons/${widget.coupon!['id']}', body: body);
      } else {
        await client.post('/api/admin/auth/coupons', body: body);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(
          content: Text(widget.coupon != null ? 'Coupon updated' : 'Coupon created', style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(content: Text('Error: $e'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
        title: Text(widget.coupon != null ? 'Edit Coupon' : 'New Coupon', style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.arrowLeft, color: AppColors.primaryDark), onPressed: () => Navigator.pop(context)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Basic Info
            _buildSectionTitle('Basic Details'),
            _buildCard(
              child: Column(
                children: [
                  _buildTextField(
                    controller: _codeCtrl,
                    label: 'Coupon Code (e.g. SUMMER24)',
                    icon: LucideIcons.ticket,
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => v!.isEmpty ? 'Code is required' : null,
                  ),
                  const Divider(height: 32, color: AppColors.background),
                  _buildDropdown(
                    label: 'Discount Type',
                    value: _discountType,
                    items: [
                      DropdownMenuItem(value: 'percentage', child: Row(children: [
                        Icon(LucideIcons.percent, size: 16, color: AppColors.primaryDark),
                        const SizedBox(width: 10),
                        Text('Percentage (%)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                      ])),
                      DropdownMenuItem(value: 'fixed', child: Row(children: [
                        Icon(LucideIcons.banknote, size: 16, color: AppColors.primaryDark),
                        const SizedBox(width: 10),
                        Text('Fixed Amount (EGP)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                      ])),
                      DropdownMenuItem(value: 'FREE_SHIPPING', child: Row(children: [
                        Icon(LucideIcons.truck, size: 16, color: AppColors.primaryDark),
                        const SizedBox(width: 10),
                        Text('Free Shipping', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                      ])),
                    ],
                    onChanged: (v) => setState(() => _discountType = v.toString()),
                  ),
                  if (_discountType != 'FREE_SHIPPING') ...[
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _valueCtrl,
                      label: 'Value',
                      icon: _discountType == 'percentage' ? LucideIcons.percent : LucideIcons.banknote,
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Conditions
            _buildSectionTitle('Usage Conditions'),
            _buildCard(
              child: Column(
                children: [
                  _buildTextField(
                    controller: _minOrderCtrl,
                    label: 'Minimum Order Value (Optional)',
                    icon: LucideIcons.shoppingCart,
                    keyboardType: TextInputType.number,
                  ),
                  if (_discountType == 'percentage') ...[
                    const Divider(height: 32, color: AppColors.background),
                    _buildTextField(
                      controller: _maxDiscountCtrl,
                      label: 'Maximum Discount (Optional)',
                      icon: LucideIcons.coins,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  const Divider(height: 32, color: AppColors.background),
                  _buildTextField(
                    controller: _usageLimitCtrl,
                    label: 'Usage Limit (Optional)',
                    icon: LucideIcons.users,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Validity
            _buildSectionTitle('Validity'),
            _buildCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectDate(context, true),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Start Date', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textMuted)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(LucideIcons.calendarDays, size: 16, color: AppColors.primaryDark),
                                    const SizedBox(width: 8),
                                    Text(_startDate != null ? _startDate!.toString().substring(0, 10) : 'Not set', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectDate(context, false),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('End Date (Optional)', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(LucideIcons.calendarOff, size: 16, color: AppColors.primaryDark),
                                    const SizedBox(width: 8),
                                    Text(_endDate != null ? _endDate!.toString().substring(0, 10) : 'Not set', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32, color: AppColors.background),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Active Status', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            Text('Can customers use this coupon right now?', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        activeThumbColor: AppColors.accent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Save Button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _hasChanges ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade500,
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(widget.coupon != null ? 'Save Changes' : 'Create Coupon', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          onChanged: (_) => setState(() {}),
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            items: items,
            onChanged: onChanged,
            icon: const Icon(LucideIcons.chevronDown, size: 18, color: AppColors.textMuted),
            dropdownColor: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            elevation: 8,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}


