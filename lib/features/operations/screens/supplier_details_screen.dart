import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:admin_app/core/widgets/app_toast.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'invoice_details_screen.dart';

class SupplierDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> supplier;
  final List<dynamic> invoices;

  const SupplierDetailsScreen({
    super.key,
    required this.supplier,
    required this.invoices,
  });

  @override
  State<SupplierDetailsScreen> createState() => _SupplierDetailsScreenState();
}

class _SupplierDetailsScreenState extends State<SupplierDetailsScreen> {
  late Map<String, dynamic> _supplier;
  late List<dynamic> _supplierInvoices;
  bool _isLoading = false;
  bool _hasChanges = false;
  final _currencyFormat = NumberFormat('#,##0.00', 'en');

  @override
  void initState() {
    super.initState();
    _supplier = Map<String, dynamic>.from(widget.supplier);
    _filterInvoices();
  }

  void _filterInvoices() {
    _supplierInvoices = widget.invoices
        .where((inv) => inv['supplierId'] == _supplier['id'])
        .toList();
    // Sort by issueDate desc
    _supplierInvoices.sort((a, b) {
      final dateA = DateTime.tryParse(a['issueDate'] ?? '') ?? DateTime(1970);
      final dateB = DateTime.tryParse(b['issueDate'] ?? '') ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });
  }

  Future<void> _makeCall(String phone) async {
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(
          content: const Text('Could not place call'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri url = Uri.parse('mailto:$email');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(
          content: const Text('Could not open email client'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _deleteSupplier() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Supplier',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        content: Text(
          'This supplier will be permanently removed. This will fail if there are linked invoices.',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      await client.delete('/api/admin/auth/procurement/${_supplier['id']}');
      
      messenger.showAppToast(AppToast.snackBar(
        content: const Text('Supplier deleted successfully'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      if (mounted) {
        Navigator.pop(context, true); // Pop with true to refresh parent list
      }
    } catch (e) {
      setState(() => _isLoading = false);
      messenger.showAppToast(AppToast.snackBar(
        content: Text('Error: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showEditSupplierDialog() {
    final nameCtrl = TextEditingController(text: _supplier['name'] ?? '');
    final contactCtrl = TextEditingController(text: _supplier['contactPerson'] ?? '');
    final emailCtrl = TextEditingController(text: _supplier['email'] ?? '');
    final phoneCtrl = TextEditingController(text: _supplier['phone'] ?? '');
    String paymentTerms = _supplier['paymentTerms'] ?? 'NET30';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Edit Supplier',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _modalField('Company Name', nameCtrl, LucideIcons.building),
                  const SizedBox(height: 12),
                  _modalField('Contact Person', contactCtrl, LucideIcons.user),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _modalField('Email', emailCtrl, LucideIcons.mail)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _modalField('Phone', phoneCtrl, LucideIcons.phone, isNumber: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Terms',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: paymentTerms,
                        isExpanded: true,
                        icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textMuted),
                        dropdownColor: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        items: ['COD', 'NET15', 'NET30', 'NET60']
                            .map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(r, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
                                ))
                            .toList(),
                        onChanged: (v) => setModalState(() => paymentTerms = v!),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.isEmpty) return;
                        final body = {
                          'name': nameCtrl.text.trim(),
                          'contactPerson': contactCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'phone': phoneCtrl.text.trim(),
                          'paymentTerms': paymentTerms,
                        };
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final token = context.read<AuthProvider>().token;
                          final client = ApiClient(token: token);
                          final res = await client.put('/api/admin/auth/procurement/${_supplier['id']}', body: body);
                          
                          if (ctx.mounted) {
                            if (mounted) {
                              setState(() {
                                _supplier = Map<String, dynamic>.from(res['supplier'] ?? body);
                                _hasChanges = true;
                              });
                            }
                            Navigator.pop(ctx);
                          }
                        } catch (e) {
                          if (mounted) {
                            messenger.showAppToast(AppToast.snackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Save Changes',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
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

  Widget _modalField(String label, TextEditingController ctrl, IconData icon, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
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

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Stats
    double totalSourced = 0;
    double totalDebt = 0;
    for (var inv in _supplierInvoices) {
      final total = (inv['grandTotal'] ?? 0).toDouble();
      totalSourced += total;
      if (inv['paymentStatus'] != 'PAID') {
        totalDebt += (inv['remainingAmount'] ?? total).toDouble();
      }
    }

    final hasPhone = _supplier['phone'] != null && _supplier['phone'].toString().trim().isNotEmpty;
    final hasEmail = _supplier['email'] != null && _supplier['email'].toString().trim().isNotEmpty;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _hasChanges) {
          // If we had changes, trigger parent refresh on pop
          Future.delayed(Duration.zero, () {
            if (context.mounted) {
              Navigator.pop(context, true);
            }
          });
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: AppColors.primaryDark),
            onPressed: () => Navigator.pop(context, _hasChanges),
          ),
          title: Text(
            'Supplier Details',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.edit3, color: AppColors.primaryDark, size: 20),
              onPressed: _showEditSupplierDialog,
            ),
            IconButton(
              icon: const Icon(LucideIcons.trash2, color: AppColors.error, size: 20),
              onPressed: _deleteSupplier,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryDark))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  // Supplier Profile Card
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
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryDark.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.building, color: AppColors.primaryDark, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _supplier['name'] ?? '',
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _supplier['contactPerson'] ?? 'No Contact Person',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        
                        // Details Rows
                        _infoRow(LucideIcons.phone, 'Phone', _supplier['phone'] ?? 'N/A', onTap: hasPhone ? () => _makeCall(_supplier['phone']) : null),
                        const SizedBox(height: 12),
                        _infoRow(LucideIcons.mail, 'Email', _supplier['email'] ?? 'N/A', onTap: hasEmail ? () => _sendEmail(_supplier['email']) : null),
                        const SizedBox(height: 12),
                        _infoRow(
                          LucideIcons.creditCard,
                          'Payment Terms',
                          _supplier['paymentTerms'] ?? 'N/A',
                          badgeText: _supplier['paymentTerms'],
                        ),
                        
                        if (hasPhone || hasEmail) ...[
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              if (hasPhone)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(LucideIcons.phoneCall, size: 16),
                                    label: const Text('Call'),
                                    onPressed: () => _makeCall(_supplier['phone']),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              if (hasPhone && hasEmail) const SizedBox(width: 12),
                              if (hasEmail)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(LucideIcons.mail, size: 16),
                                    label: const Text('Email'),
                                    onPressed: () => _sendEmail(_supplier['email']),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Stats row
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _statCard(
                            'Total Spend',
                            'EGP ${_currencyFormat.format(totalSourced)}',
                            LucideIcons.shoppingCart,
                            AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            'Open Invoices',
                            '${_supplierInvoices.length} Bills',
                            LucideIcons.fileText,
                            AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _statCard(
                    'Outstanding Debt',
                    'EGP ${_currencyFormat.format(totalDebt)}',
                    LucideIcons.alertCircle,
                    totalDebt > 0 ? AppColors.error : AppColors.success,
                    isWide: true,
                  ),
                  const SizedBox(height: 24),

                  // Supplier Invoices Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PURCHASE INVOICES',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '${_supplierInvoices.length} Found',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_supplierInvoices.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(LucideIcons.fileX2, size: 40, color: AppColors.textMuted.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text(
                              'No invoices recorded for this supplier',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._supplierInvoices.map((inv) => _buildInvoiceCard(inv)),
                ],
              ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {VoidCallback? onTap, String? badgeText}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        ),
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: onTap != null ? AppColors.primaryDark : AppColors.textPrimary,
                decoration: onTap != null ? TextDecoration.underline : TextDecoration.none,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (badgeText != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeText,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, {bool isWide = false}) {
    final Widget child = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: isWide ? 18 : 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: child,
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> inv) {
    final dateStr = inv['issueDate'] ?? '';
    final date = DateTime.tryParse(dateStr)?.toLocal() ?? DateTime.now();
    final status = inv['status'] ?? 'DRAFT';
    final payment = inv['paymentStatus'] ?? 'UNPAID';
    final total = (inv['grandTotal'] ?? 0).toDouble();

    final invMap = Map<String, dynamic>.from(inv);
    if (invMap['supplier'] == null) {
      invMap['supplier'] = _supplier;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InvoiceDetailsScreen(
              invoice: invMap,
            ),
          ),
        ).then((shouldReload) {
          if (shouldReload == true) {
            _reloadInvoices();
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.receipt, color: AppColors.primaryDark, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv['invoiceNumber'] ?? '',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      Text(
                        '${date.day}/${date.month}/${date.year}',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(LucideIcons.moreVertical, color: AppColors.textMuted, size: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (v) {
                    if (v == 'delete') _deleteInvoice(inv['id']);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(LucideIcons.trash2, size: 16, color: Colors.red),
                          SizedBox(width: 10),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'EGP ${_currencyFormat.format(total)}',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                Row(
                  children: [
                    _badge(status, status == 'POSTED' ? AppColors.success : AppColors.warning),
                    const SizedBox(width: 8),
                    _badge(
                      payment,
                      payment == 'PAID'
                          ? AppColors.success
                          : (payment == 'PARTIAL' ? AppColors.warning : AppColors.error),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  Future<void> _reloadInvoices() async {
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final invoicesData = await client.get('/api/admin/auth/procurement/invoices');
      if (mounted) {
        setState(() {
          widget.invoices.clear();
          widget.invoices.addAll(invoicesData['invoices'] ?? []);
          _filterInvoices();
          _hasChanges = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _deleteInvoice(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Invoice',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this purchase invoice?',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      await client.delete('/api/admin/auth/procurement/invoices/$id');
      
      messenger.showAppToast(AppToast.snackBar(
        content: const Text('Invoice deleted successfully'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      
      await _reloadInvoices();
    } catch (e) {
      if (mounted) {
        messenger.showAppToast(AppToast.snackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}
