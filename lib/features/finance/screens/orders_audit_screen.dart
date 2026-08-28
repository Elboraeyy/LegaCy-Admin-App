import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:admin_app/core/widgets/app_toast.dart';
import 'package:intl/intl.dart';
import 'package:admin_app/core/widgets/app_shimmer.dart';

class OrdersAuditScreen extends StatefulWidget {
  const OrdersAuditScreen({super.key});

  @override
  State<OrdersAuditScreen> createState() => _OrdersAuditScreenState();
}

class _OrdersAuditScreenState extends State<OrdersAuditScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _safes = [];
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  final _currencyFormat = NumberFormat('#,##0.00', 'en');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _loadOrders();
    });
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentTab => _tabController.index == 0 ? 'pending' : 'audited';

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final res = await client.get('/api/admin/auth/finance/orders-audit?tab=$_currentTab&month=$_month&year=$_year');
      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(res['orders'] ?? []);
          _summary = Map<String, dynamic>.from(res['summary'] ?? {});
          _safes = List<Map<String, dynamic>>.from(res['safes'] ?? []);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAuditSheet(Map<String, dynamic> order) {
    final bool isAudited = order['isFinanciallyAudited'] == true;
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);

    // 1. Packaging Cost: product's specs.additionalCosts (sum for all products, multiplied by their quantities)
    double autoPackaging = 0.0;
    for (final item in items) {
      final prod = item['product'];
      if (prod != null && prod['specs'] != null) {
        final addCosts = double.tryParse(prod['specs']['additionalCosts']?.toString() ?? '') ?? 0.0;
        autoPackaging += addCosts * (item['quantity'] ?? 1);
      }
    }
    double initialPackaging = isAudited ? (order['packagingCost'] ?? 0.0).toDouble() : autoPackaging;

    // 2. Shipping Cost: from order's shipping cost
    double initialShipping = isAudited ? (order['actualShippingCost'] ?? 0.0).toDouble() : (order['shippingCost'] ?? 0.0).toDouble();

    // 3. Wholesale Price list & Total Wholesale Price
    final itemWholesaleControllers = items.map((item) {
      double initialVal = 0.0;
      if (isAudited) {
        initialVal = (item['costAtPurchase'] ?? 0.0).toDouble();
      } else {
        final prod = item['product'];
        if (prod != null && prod['specs'] != null) {
          initialVal = double.tryParse(prod['specs']['supplierPrice']?.toString() ?? '') ?? 0.0;
        } else if (prod != null && prod['costPrice'] != null) {
          initialVal = (prod['costPrice'] as num).toDouble();
        } else {
          initialVal = (item['costAtPurchase'] ?? 0.0).toDouble();
        }
      }
      return TextEditingController(text: initialVal.toString());
    }).toList();

    double calculateTotalCOGS() {
      double sum = 0.0;
      for (int i = 0; i < items.length; i++) {
        final val = double.tryParse(itemWholesaleControllers[i].text) ?? 0.0;
        sum += val * (items[i]['quantity'] ?? 1);
      }
      return sum;
    }

    final wholesaleCtrl = TextEditingController(
      text: (isAudited ? (order['wholesaleCost'] ?? calculateTotalCOGS()) : calculateTotalCOGS()).toString()
    );

    // 4. Extra Expenses: default of 25 EGP per product in the order (e.g. 4 products = 100)
    int totalQty = items.fold(0, (s, i) => s + ((i['quantity'] ?? 1) as int));
    double initialExtra = isAudited ? (order['extraExpenses'] ?? 0.0).toDouble() : (totalQty * 25.0);

    final packagingCtrl = TextEditingController(text: initialPackaging.toString());
    final shippingCtrl = TextEditingController(text: initialShipping.toString());
    final extraCtrl = TextEditingController(text: initialExtra.toString());
    final notesCtrl = TextEditingController(text: order['auditNotes'] ?? '');
    String? selectedSafeId = order['auditSafeId'];
    // Default to Cash safe if no safe is already selected
    if (selectedSafeId == null && _safes.isNotEmpty) {
      final cashSafe = _safes.firstWhere(
        (s) => (s['name'] as String).toLowerCase().contains('cash'),
        orElse: () => _safes.first,
      );
      selectedSafeId = cashSafe['id'] as String;
    }

    double calcProfit() {
      final revenue = (order['totalPrice'] ?? 0).toDouble();
      final w = double.tryParse(wholesaleCtrl.text) ?? 0;
      final p = double.tryParse(packagingCtrl.text) ?? 0;
      final s = double.tryParse(shippingCtrl.text) ?? 0;
      final e = double.tryParse(extraCtrl.text) ?? 0;
      return revenue - w - p - s - e;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final profit = calcProfit();
          final revenue = (order['totalPrice'] ?? 0).toDouble();
          final margin = revenue > 0 ? (profit / revenue * 100) : 0.0;

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.receipt, size: 20, color: AppColors.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Order #${order['orderNumber']}', style: GoogleFonts.playfairDisplay(
                              fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primaryDark,
                            )),
                            Text(order['customerName'] ?? 'Guest', style: GoogleFonts.inter(
                              fontSize: 13, color: AppColors.textMuted,
                            )),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('EGP ${_currencyFormat.format(revenue)}', style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryDark,
                          )),
                          Text(order['paymentMethod'] ?? '', style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.textMuted,
                          )),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Profit preview
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: profit >= 0 ? AppColors.success.withValues(alpha: 0.08) : AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: profit >= 0 ? AppColors.success.withValues(alpha: 0.2) : AppColors.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _profitStat('Net Profit', 'EGP ${_currencyFormat.format(profit)}', profit >= 0 ? AppColors.success : AppColors.error),
                      Container(width: 1, height: 30, color: AppColors.divider),
                      _profitStat('Margin', '${margin.toStringAsFixed(1)}%', profit >= 0 ? AppColors.success : AppColors.error),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Form
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      const SizedBox(height: 8),
                      _buildOrderQuickDetailsCard(order),
                      const SizedBox(height: 8),

                      // Wholesale Cost Per Item (if multiple items)
                      if (items.length > 1) ...[
                        Text('WHOLESALE COST PER ITEM', style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1,
                        )),
                        const SizedBox(height: 8),
                        ...List.generate(items.length, (index) {
                          final item = items[index];
                          final ctrl = itemWholesaleControllers[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextField(
                              controller: ctrl,
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                setSheetState(() {
                                  double sum = 0.0;
                                  for (int j = 0; j < items.length; j++) {
                                    final itemVal = double.tryParse(itemWholesaleControllers[j].text) ?? 0.0;
                                    sum += itemVal * (items[j]['quantity'] ?? 1);
                                  }
                                  wholesaleCtrl.text = sum.toString();
                                });
                              },
                              decoration: InputDecoration(
                                labelText: '${item['name']} (x${item['quantity']})',
                                prefixIcon: const Icon(LucideIcons.package, size: 18),
                                prefixText: 'EGP ',
                                filled: true,
                                fillColor: AppColors.background,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.cardBorder)),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                      ],

                      _auditField(
                        'Total Wholesale Cost (COGS)',
                        wholesaleCtrl,
                        LucideIcons.package,
                        () => setSheetState(() {}),
                        readOnly: items.length > 1,
                      ),
                      _auditField('Packaging Cost', packagingCtrl, LucideIcons.box, () => setSheetState(() {})),
                      _auditField('Actual Shipping Cost', shippingCtrl, LucideIcons.truck, () => setSheetState(() {})),
                      _auditField('Extra Expenses', extraCtrl, LucideIcons.circleDollarSign, () => setSheetState(() {})),
                      const SizedBox(height: 12),
                      // Safe selection
                      DropdownButtonFormField<String>(
                        value: selectedSafeId,
                        isExpanded: true,
                        icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textMuted),
                        dropdownColor: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          labelText: 'Money received in',
                          prefixIcon: const Icon(LucideIcons.landmark, size: 18, color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.cardBorder)),
                        ),
                        items: _safes.map((s) => DropdownMenuItem(
                          value: s['id'] as String,
                          child: Text(s['name'], style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
                        )).toList(),
                        onChanged: (v) => setSheetState(() => selectedSafeId = v),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Notes (optional)',
                          prefixIcon: const Icon(LucideIcons.stickyNote, size: 18),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.cardBorder)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Items breakdown
                      if (items.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('ORDER ITEMS', style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1,
                        )),
                        const SizedBox(height: 8),
                        ...items.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text('${item['name']} x${item['quantity']}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              Text('Cost: ${_currencyFormat.format((item['costAtPurchase'] ?? 0).toDouble())}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                              const SizedBox(width: 8),
                              Text('Price: ${_currencyFormat.format((item['price'] ?? 0).toDouble())}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                // Confirm button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: const Icon(LucideIcons.checkCircle, size: 20),
                      label: Text('Confirm Audit', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          final token = context.read<AuthProvider>().token;
                          final client = ApiClient(token: token);
                          final body = {
                            'orderId': order['id'],
                            'wholesaleCost': double.tryParse(wholesaleCtrl.text) ?? 0,
                            'packagingCost': double.tryParse(packagingCtrl.text) ?? 0,
                            'actualShippingCost': double.tryParse(shippingCtrl.text) ?? 0,
                            'extraExpenses': double.tryParse(extraCtrl.text) ?? 0,
                            'auditSafeId': selectedSafeId,
                            'auditNotes': notesCtrl.text.isNotEmpty ? notesCtrl.text : null,
                            'itemCosts': List.generate(items.length, (idx) => {
                              'itemId': items[idx]['id'],
                              'cost': double.tryParse(itemWholesaleControllers[idx].text) ?? 0.0,
                            }),
                          };
                          await client.put('/api/admin/auth/finance/orders-audit', body: body);
                          _loadOrders();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(
                              content: Text('Order #${order['orderNumber']} audited ✓'),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(
                              content: Text('Error: $e'),
                              backgroundColor: AppColors.error,
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _profitStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  Widget _auditField(String label, TextEditingController ctrl, IconData icon, VoidCallback onChanged, {bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        onChanged: (_) => onChanged(),
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18),
          prefixText: 'EGP ',
          filled: true,
          fillColor: readOnly ? AppColors.background.withValues(alpha: 0.5) : AppColors.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.cardBorder)),
        ),
      ),
    );
  }

  Widget _buildOrderQuickDetailsCard(Map<String, dynamic> order) {
    final customerName = order['customerName'] ?? 'Guest';
    final customerPhone = order['customerPhone'] ?? '';
    final gov = order['shippingGovernorate'] ?? '';
    final city = order['shippingCity'] ?? '';
    final payment = order['paymentMethod'] ?? '';
    final totalPrice = order['totalPrice'] ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.user, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  customerName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (customerPhone.isNotEmpty) ...[
                const SizedBox(width: 8),
                const Icon(LucideIcons.phone, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  customerPhone,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(LucideIcons.mapPin, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$gov${gov.isNotEmpty && city.isNotEmpty ? ' - ' : ''}$city',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.creditCard, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    payment.toString().toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                'Total: EGP ${_currencyFormat.format(totalPrice)}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        int tmpMonth = _month;
        int tmpYear = _year;
        return StatefulBuilder(
          builder: (ctx, ss) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Select Month', style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(icon: const Icon(LucideIcons.chevronLeft), onPressed: () => ss(() => tmpYear--)),
                    Text('$tmpYear', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
                    IconButton(icon: const Icon(LucideIcons.chevronRight), onPressed: () => ss(() => tmpYear++)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: List.generate(12, (i) {
                    final m = i + 1;
                    final selected = m == tmpMonth;
                    return GestureDetector(
                      onTap: () => ss(() => tmpMonth = m),
                      child: Container(
                        width: 70, padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primaryDark : AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selected ? AppColors.primaryDark : AppColors.cardBorder),
                        ),
                        child: Center(child: Text(
                          DateFormat('MMM').format(DateTime(2026, m)),
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textPrimary),
                        )),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    child: const Text('Apply'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() { _month = tmpMonth; _year = tmpYear; });
                      _loadOrders();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _summary['pendingCount'] ?? 0;
    final audited = _summary['auditedCount'] ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text('Order Audit', style: GoogleFonts.playfairDisplay(
          fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primaryDark,
        )),
        actions: [
          TextButton.icon(
            icon: const Icon(LucideIcons.calendar, size: 16),
            label: Text('${DateFormat('MMM').format(DateTime(_year, _month))} $_year',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            onPressed: _showMonthPicker,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(62),
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
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: [
                Tab(text: 'Pending ($pending)'),
                Tab(text: 'Audited ($audited)'),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: 5,
              itemBuilder: (ctx, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      const AppShimmer(width: 44, height: 44, borderRadius: 12),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            AppShimmer(width: 100, height: 14),
                            SizedBox(height: 6),
                            AppShimmer(width: 80, height: 10),
                          ],
                        ),
                      ),
                      const AppShimmer(width: 80, height: 16),
                      const SizedBox(width: 4),
                      const Icon(LucideIcons.chevronRight, size: 16, color: Colors.transparent),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadOrders,
              color: AppColors.primaryDark,
              child: _orders.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                _currentTab == 'pending' ? LucideIcons.clipboardCheck : LucideIcons.checkCircle2,
                                size: 48,
                                color: AppColors.textMuted.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _currentTab == 'pending' ? 'All orders audited!' : 'No audited orders yet',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _orders.length,
                      itemBuilder: (ctx, i) => _buildOrderCard(_orders[i]),
                    ),
            ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final totalPrice = (order['totalPrice'] ?? 0).toDouble();
    final netProfit = order['netProfit'] as num?;
    final isAudited = order['isFinanciallyAudited'] == true;

    return GestureDetector(
      onTap: () => _showAuditSheet(order),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isAudited ? AppColors.success.withValues(alpha: 0.3) : AppColors.cardBorder),
          boxShadow: [
            BoxShadow(color: AppColors.cardBorder.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: isAudited ? AppColors.success.withValues(alpha: 0.1) : AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text('#${order['orderNumber']}', style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w800,
                  color: isAudited ? AppColors.success : AppColors.accent,
                )),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order['customerName'] ?? 'Guest', style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                  )),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(order['deliveredAt']),
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('EGP ${_currencyFormat.format(totalPrice)}', style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                )),
                if (isAudited && netProfit != null)
                  Text(
                    'Profit: ${_currencyFormat.format(netProfit.toDouble())}',
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: netProfit >= 0 ? AppColors.success : AppColors.error,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return DateFormat('dd MMM yyyy').format(dt.toLocal());
  }
}



