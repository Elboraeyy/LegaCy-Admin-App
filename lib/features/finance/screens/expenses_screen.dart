import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:admin_app/core/widgets/app_toast.dart';
import 'package:intl/intl.dart';
import 'package:admin_app/features/finance/screens/category_details_screen.dart';
import 'package:admin_app/core/widgets/app_shimmer.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _amortized = [];
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _safes = [];
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  final _currencyFormat = NumberFormat('#,##0.00', 'en');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadExpenses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    setState(() => _loading = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final res = await client.get('/api/admin/auth/finance/expenses?month=$_month&year=$_year');
      debugPrint('Expenses GET Response: $res');
      if (mounted) {
        setState(() {
          _expenses = (res['expenses'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
          _amortized = (res['amortizedExpenses'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
          _stats = Map<String, dynamic>.from(res['stats'] as Map? ?? {});
          _categories = (res['categories'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
          _safes = (res['safes'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
          _loading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Error loading expenses: $e');
      debugPrint(stack.toString());
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddExpenseSheet() {
    debugPrint('Show Add Expense Sheet. Categories count: ${_categories.length}');
    debugPrint('Categories content: $_categories');
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String? categoryId = _categories.isNotEmpty ? _categories.first['id'] : null;
    String? subcategoryId;
    String? safeId;
    bool isAmortized = false;
    String selectedType = 'OPERATING';
    final spreadCtrl = TextEditingController(text: '1');
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          if (categoryId == null && _categories.isNotEmpty) {
            categoryId = _categories.first['id'];
          }
          final selectedCat = _categories.firstWhere(
            (c) => c['id'] == categoryId,
            orElse: () => {'children': []},
          );
          final subcats = (selectedCat['children'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];

          Widget buildTypeOption(String type, String label, bool isSelected, Color activeColor) {
            return Expanded(
              child: GestureDetector(
                onTap: () => ss(() {
                  selectedType = type;
                  isAmortized = type == 'AMORTIZED';
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? activeColor.withValues(alpha: 0.1) : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? activeColor : AppColors.cardBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? activeColor : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.receipt, size: 20, color: AppColors.error),
                      ),
                      const SizedBox(width: 12),
                      Text('New Expense', style: GoogleFonts.playfairDisplay(
                        fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primaryDark,
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(labelText: 'Description', hintText: 'e.g. Facebook Ads May'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Amount', prefixText: 'EGP '),
                        onChanged: (_) => ss(() {}),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2025),
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
                            ss(() {
                              selectedDate = picked;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Expense Date',
                            prefixIcon: Icon(LucideIcons.calendar, size: 20),
                          ),
                          child: Text(
                            DateFormat('dd MMM yyyy').format(selectedDate),
                            style: GoogleFonts.inter(fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Expense Type Selector
                      Text('EXPENSE TYPE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          buildTypeOption('OPERATING', 'Regular', selectedType == 'OPERATING', AppColors.error),
                          const SizedBox(width: 8),
                          buildTypeOption('AMORTIZED', 'Amortized', selectedType == 'AMORTIZED', AppColors.info),
                          const SizedBox(width: 8),
                          buildTypeOption('CAPITAL', 'Capital/Cost', selectedType == 'CAPITAL', const Color(0xFFD4AF37)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (selectedType == 'AMORTIZED') ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: spreadCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Number of months',
                                  hintText: 'e.g. 6',
                                  isDense: true,
                                ),
                                onChanged: (_) => ss(() {}),
                              ),
                              if (amountCtrl.text.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Monthly: EGP ${_currencyFormat.format(((double.tryParse(amountCtrl.text) ?? 0) / (int.tryParse(spreadCtrl.text) ?? 1)))}',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.info),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (_categories.isEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.alertTriangle, color: AppColors.error, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'No categories found. Please create a category first in the Categories tab.',
                                  style: GoogleFonts.inter(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        DropdownButtonFormField<String>(
                          value: categoryId,
                          isExpanded: true,
                          icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textMuted),
                          dropdownColor: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                          decoration: const InputDecoration(labelText: 'Category'),
                          items: _categories.map((c) => DropdownMenuItem(
                            value: c['id'] as String,
                            child: Text(c['name'], style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
                          )).toList(),
                          onChanged: (v) => ss(() { categoryId = v; subcategoryId = null; }),
                        ),
                      ],
                      if (subcats.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: subcategoryId,
                          isExpanded: true,
                          icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textMuted),
                          dropdownColor: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                          decoration: const InputDecoration(labelText: 'Subcategory (optional)'),
                          items: [
                            DropdownMenuItem(value: null, child: Text('None', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted))),
                            ...subcats.map((c) => DropdownMenuItem(
                              value: c['id'] as String,
                              child: Text(c['name'], style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
                            )),
                          ],
                          onChanged: (v) => ss(() => subcategoryId = v),
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: safeId,
                        isExpanded: true,
                        icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textMuted),
                        dropdownColor: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                        decoration: const InputDecoration(labelText: 'Paid from (Safe)'),
                        items: [
                          DropdownMenuItem(value: null, child: Text('Not specified', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted))),
                          ..._safes.map((s) => DropdownMenuItem(
                            value: s['id'] as String,
                            child: Text(s['name'], style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
                          )),
                        ],
                        onChanged: (v) => ss(() => safeId = v),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: const Icon(LucideIcons.plus, size: 20),
                      label: Text('Add Expense', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedType == 'CAPITAL'
                            ? const Color(0xFFD4AF37)
                            : (selectedType == 'AMORTIZED' ? AppColors.info : AppColors.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        if (descCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;
                        Navigator.pop(ctx);
                        try {
                          final token = context.read<AuthProvider>().token;
                          final client = ApiClient(token: token);
                          await client.post('/api/admin/auth/finance/expenses', body: {
                            'description': descCtrl.text,
                            'amount': double.tryParse(amountCtrl.text) ?? 0,
                            'categoryId': categoryId,
                            'subcategoryId': subcategoryId,
                            'safeId': safeId,
                            'isAmortized': isAmortized,
                            'expenseType': selectedType,
                            'spreadMonths': isAmortized ? (int.tryParse(spreadCtrl.text) ?? 1) : 1,
                            'date': selectedDate.toIso8601String(),
                          });
                          _loadExpenses();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(
                              content: const Text('Expense added'),
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

  void _showEditExpenseSheet(Map<String, dynamic> expense) {
    final descCtrl   = TextEditingController(text: expense['description'] ?? '');
    final amountCtrl = TextEditingController(text: (expense['amount'] ?? '').toString());
    final spreadCtrl = TextEditingController(text: (expense['spreadMonths'] ?? 1).toString());

    String? categoryId   = (expense['category'] as Map?)?['id'];
    String? subcategoryId = (expense['subcategory'] as Map?)?['id'];
    String? safeId       = (expense['safe'] as Map?)?['id'];
    String  selectedType = expense['expenseType'] ?? 'OPERATING';
    bool    isAmortized  = selectedType == 'AMORTIZED';
    DateTime selectedDate = expense['date'] != null
        ? DateTime.tryParse(expense['date'])?.toLocal() ?? DateTime.now()
        : DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          final selectedCat = _categories.firstWhere(
            (c) => c['id'] == categoryId,
            orElse: () => {'children': []},
          );
          final subcats = (selectedCat['children'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];

          Widget buildTypeOption(String type, String label, bool isSelected, Color activeColor) {
            return Expanded(
              child: GestureDetector(
                onTap: () => ss(() {
                  selectedType = type;
                  isAmortized  = type == 'AMORTIZED';
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? activeColor.withValues(alpha: 0.1) : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? activeColor : AppColors.cardBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? activeColor : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.edit2, size: 20, color: AppColors.primaryDark),
                      ),
                      const SizedBox(width: 12),
                      Text('Edit Expense', style: GoogleFonts.playfairDisplay(
                        fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primaryDark,
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(labelText: 'Description'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Amount', prefixText: 'EGP '),
                        onChanged: (_) => ss(() {}),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2025),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            builder: (context, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppColors.primaryDark,
                                  onPrimary: Colors.white,
                                  onSurface: AppColors.textPrimary,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) ss(() => selectedDate = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Expense Date',
                            prefixIcon: Icon(LucideIcons.calendar, size: 20),
                          ),
                          child: Text(
                            DateFormat('dd MMM yyyy').format(selectedDate),
                            style: GoogleFonts.inter(fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('EXPENSE TYPE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          buildTypeOption('OPERATING', 'Regular',     selectedType == 'OPERATING', AppColors.error),
                          const SizedBox(width: 8),
                          buildTypeOption('AMORTIZED', 'Amortized',   selectedType == 'AMORTIZED', AppColors.info),
                          const SizedBox(width: 8),
                          buildTypeOption('CAPITAL',   'Capital/Cost', selectedType == 'CAPITAL',   const Color(0xFFD4AF37)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (isAmortized) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: spreadCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Number of months',
                                  isDense: true,
                                ),
                                onChanged: (_) => ss(() {}),
                              ),
                              if (amountCtrl.text.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Monthly: EGP ${_currencyFormat.format(((double.tryParse(amountCtrl.text) ?? 0) / (int.tryParse(spreadCtrl.text) ?? 1)))}',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.info),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      DropdownButtonFormField<String>(
                        value: _categories.any((c) => c['id'] == categoryId) ? categoryId : null,
                        isExpanded: true,
                        icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textMuted),
                        dropdownColor: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: _categories.map((c) => DropdownMenuItem(
                          value: c['id'] as String,
                          child: Text(c['name'], style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
                        )).toList(),
                        onChanged: (v) => ss(() { categoryId = v; subcategoryId = null; }),
                      ),
                      if (subcats.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: subcats.any((s) => s['id'] == subcategoryId) ? subcategoryId : null,
                          isExpanded: true,
                          icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textMuted),
                          dropdownColor: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                          decoration: const InputDecoration(labelText: 'Subcategory (optional)'),
                          items: [
                            DropdownMenuItem(value: null, child: Text('None', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted))),
                            ...subcats.map((c) => DropdownMenuItem(
                              value: c['id'] as String,
                              child: Text(c['name'], style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
                            )),
                          ],
                          onChanged: (v) => ss(() => subcategoryId = v),
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _safes.any((s) => s['id'] == safeId) ? safeId : null,
                        isExpanded: true,
                        icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textMuted),
                        dropdownColor: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                        decoration: const InputDecoration(labelText: 'Paid from (Safe)'),
                        items: [
                          DropdownMenuItem(value: null, child: Text('Not specified', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted))),
                          ..._safes.map((s) => DropdownMenuItem(
                            value: s['id'] as String,
                            child: Text(s['name'], style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
                          )),
                        ],
                        onChanged: (v) => ss(() => safeId = v),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: const Icon(LucideIcons.save, size: 20),
                      label: Text('Save Changes', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedType == 'CAPITAL'
                            ? const Color(0xFFD4AF37)
                            : (selectedType == 'AMORTIZED' ? AppColors.info : AppColors.primaryDark),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        if (descCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;
                        Navigator.pop(ctx);
                        try {
                          final token = context.read<AuthProvider>().token;
                          final client = ApiClient(token: token);
                          await client.put('/api/admin/auth/finance/expenses', body: {
                            'id': expense['id'],
                            'description': descCtrl.text,
                            'amount': double.tryParse(amountCtrl.text) ?? 0,
                            'date': selectedDate.toIso8601String(),
                            'categoryId': categoryId,
                            'subcategoryId': subcategoryId,
                            'safeId': safeId,
                            'expenseType': selectedType,
                            'spreadMonths': isAmortized ? (int.tryParse(spreadCtrl.text) ?? 1) : 1,
                          });
                          _loadExpenses();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(
                              content: const Text('Expense updated'),
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
                      _loadExpenses();
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

  void _showAddCategoryDialog() {
    final nameCtrl = TextEditingController();
    String? parentId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('New Category', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Category Name')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: parentId,
                isExpanded: true,
                icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textMuted),
                dropdownColor: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                decoration: const InputDecoration(labelText: 'Parent (for subcategory)'),
                items: [
                  DropdownMenuItem(value: null, child: Text('None (Top-level)', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted))),
                  ..._categories.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'], style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)))),
                ],
                onChanged: (v) => ss(() => parentId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final token = context.read<AuthProvider>().token;
                  final client = ApiClient(token: token);
                  await client.post('/api/admin/auth/finance/expense-categories', body: {
                    'name': nameCtrl.text,
                    'parentId': parentId,
                  });
                  _loadExpenses();
                } catch (e) {
                  // ignore
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCategoryDialog(Map<String, dynamic> category) {
    final nameCtrl = TextEditingController(text: category['name']);
    final budgetLimitCtrl = TextEditingController(text: category['budgetLimit']?.toString() ?? '');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Category', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Category Name')),
            const SizedBox(height: 12),
            TextField(
              controller: budgetLimitCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Monthly Budget Limit (optional)', prefixText: 'EGP '),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final token = context.read<AuthProvider>().token;
                final client = ApiClient(token: token);
                await client.put('/api/admin/auth/finance/expense-categories', body: {
                  'id': category['id'],
                  'name': nameCtrl.text,
                  'budgetLimit': budgetLimitCtrl.text.isNotEmpty ? (double.tryParse(budgetLimitCtrl.text) ?? 0) : null,
                });
                _loadExpenses();
                if (mounted) {
                  ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(
                    content: const Text('Category updated'),
                    backgroundColor: AppColors.success,
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(
                    content: Text('Error: $e'),
                    backgroundColor: AppColors.error,
                  ));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddSubcategoryDialog(String parentId, String parentName) {
    final nameCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add Subcategory to $parentName', style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Subcategory Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final token = context.read<AuthProvider>().token;
                final client = ApiClient(token: token);
                await client.post('/api/admin/auth/finance/expense-categories', body: {
                  'name': nameCtrl.text,
                  'parentId': parentId,
                });
                _loadExpenses();
                if (mounted) {
                  ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(
                    content: const Text('Subcategory added'),
                    backgroundColor: AppColors.success,
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(
                    content: Text('Error: $e'),
                    backgroundColor: AppColors.error,
                  ));
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(Map<String, dynamic> category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Category?', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600, color: AppColors.error)),
        content: Text('Are you sure you want to delete "${category['name']}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final token = context.read<AuthProvider>().token;
                final client = ApiClient(token: token);
                await client.delete('/api/admin/auth/finance/expense-categories?id=${category['id']}');
                _loadExpenses();
                if (mounted) {
                  ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(
                    content: const Text('Category deleted'),
                    backgroundColor: AppColors.success,
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(
                    content: Text('Failed: $e'),
                    backgroundColor: AppColors.error,
                  ));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> cat) {
    final subcats = List<Map<String, dynamic>>.from(cat['children'] ?? []);
    final budgetLimit = cat['budgetLimit'] != null ? (cat['budgetLimit'] as num).toDouble() : null;
    final count = cat['expenseCount'] ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryDetailsScreen(
              category: cat,
              initialMonth: _month,
              initialYear: _year,
            ),
          ),
        ).then((_) => _loadExpenses());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Parent Category Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.folder, size: 18, color: AppColors.primaryDark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat['name'] ?? '',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$count expenses${budgetLimit != null ? ' • Budget: EGP ${_currencyFormat.format(budgetLimit)}' : ''}',
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  // Actions
                  IconButton(
                    icon: const Icon(LucideIcons.plus, size: 16, color: AppColors.primaryDark),
                    onPressed: () => _showAddSubcategoryDialog(cat['id'], cat['name']),
                    tooltip: 'Add Subcategory',
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.edit2, size: 16, color: AppColors.textMuted),
                    onPressed: () => _showEditCategoryDialog(cat),
                    tooltip: 'Edit Category',
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.error),
                    onPressed: () => _confirmDeleteCategory(cat),
                    tooltip: 'Delete Category',
                  ),
                ],
              ),
            ),
            if (subcats.isNotEmpty) ...[
              const Divider(height: 1, indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.only(left: 32, right: 16, top: 8, bottom: 8),
                child: Column(
                  children: subcats.map((sub) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            sub['name'] ?? '',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.edit2, size: 14, color: AppColors.textMuted),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showEditCategoryDialog(sub),
                          tooltip: 'Edit Subcategory',
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(LucideIcons.trash2, size: 14, color: AppColors.error),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _confirmDeleteCategory(sub),
                          tooltip: 'Delete Subcategory',
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _buildFAB() {
    if (_tabController.index == 0) {
      // Expenses tab
      return FloatingActionButton.extended(
        onPressed: _showAddExpenseSheet,
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(LucideIcons.plus, size: 20),
        label: Text('New Expense', style: GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      );
    } else if (_tabController.index == 1) {
      // Categories tab
      return FloatingActionButton.extended(
        onPressed: _showAddCategoryDialog,
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(LucideIcons.plus, size: 20),
        label: Text('New Category', style: GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final totalDirect = (_stats['totalDirectExpenses'] ?? 0).toDouble();
    final totalAmort = (_stats['totalAmortizedThisMonth'] ?? 0).toDouble();
    final totalCapital = (_stats['totalCapitalExpenses'] ?? 0).toDouble();
    final totalAll = (_stats['totalExpensesThisMonth'] ?? 0).toDouble();
    final breakdown = List<Map<String, dynamic>>.from(_stats['categoryBreakdown'] ?? []);

    // Group direct expenses by date
    final Map<String, List<Map<String, dynamic>>> groupedExpenses = {};
    for (final exp in _expenses) {
      if (exp['date'] == null) continue;
      final date = DateTime.parse(exp['date']).toLocal();
      final key = DateFormat('MMMM dd, yyyy').format(date);
      if (!groupedExpenses.containsKey(key)) {
        groupedExpenses[key] = [];
      }
      groupedExpenses[key]!.add(exp);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: _buildFAB(),
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text('Expenses', style: GoogleFonts.playfairDisplay(
          fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primaryDark,
        )),
        actions: [
          TextButton.icon(
            icon: const Icon(LucideIcons.calendar, size: 16),
            label: Text(
              DateFormat('MMM yyyy').format(DateTime(_year, _month)),
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
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'Expenses'),
                Tab(text: 'Categories'),
                Tab(text: 'Analytics'),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                const AppShimmer(width: double.infinity, height: 180, borderRadius: 20),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: const AppShimmer(width: double.infinity, height: 48, borderRadius: 14)),
                    const SizedBox(width: 12),
                    Expanded(child: const AppShimmer(width: double.infinity, height: 48, borderRadius: 14)),
                  ],
                ),
                const SizedBox(height: 24),
                const AppShimmer(width: 150, height: 14),
                const SizedBox(height: 12),
                ...List.generate(3, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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
                              AppShimmer(width: 140, height: 14),
                              SizedBox(height: 6),
                              AppShimmer(width: 80, height: 12),
                            ],
                          ),
                        ),
                        const AppShimmer(width: 90, height: 16),
                      ],
                    ),
                  ),
                )),
              ],
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Expenses List
                RefreshIndicator(
                  onRefresh: _loadExpenses,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      // Summary card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.error.withValues(alpha: 0.9), const Color(0xFFC62828)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('MMMM yyyy').format(DateTime(_year, _month)),
                              style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                            ),
                            const SizedBox(height: 8),
                            Text('EGP ${_currencyFormat.format(totalAll)}',
                              style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _miniStat('Operating', totalDirect, Colors.white),
                                const SizedBox(width: 16),
                                _miniStat('Amortized', totalAmort, Colors.white),
                                const SizedBox(width: 16),
                                _miniStat('Capital', totalCapital, Colors.white),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_amortized.isNotEmpty) ...[
                        Text('AMORTIZED THIS MONTH', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        ..._amortized.map((e) => _buildExpenseItem(e, isAmortized: true)),
                        const SizedBox(height: 16),
                      ],
                      Text('DIRECT EXPENSES', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1)),
                      const SizedBox(height: 12),
                      if (_expenses.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(child: Text('No expenses this month', style: GoogleFonts.inter(color: AppColors.textMuted))),
                        )
                      else
                        ...groupedExpenses.entries.expand((entry) => [
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4),
                            child: Text(
                              entry.key,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          ...entry.value.map((e) => _buildExpenseItem(e)),
                          const SizedBox(height: 8),
                        ]),
                    ],
                  ),
                ),
                // Tab 2: Categories List
                RefreshIndicator(
                  onRefresh: _loadExpenses,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      Text('EXPENSE CATEGORIES', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      if (_categories.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(child: Text('No categories created yet', style: GoogleFonts.inter(color: AppColors.textMuted))),
                        )
                      else
                        ..._categories.map((cat) => _buildCategoryCard(cat)),
                    ],
                  ),
                ),
                // Tab 3: Analytics
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    Text('SPENDING BY CATEGORY', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    if (breakdown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(child: Text('No data yet', style: GoogleFonts.inter(color: AppColors.textMuted))),
                      )
                    else
                      ...breakdown.map((cat) {
                        final pct = totalDirect > 0 ? (cat['total'] ?? 0).toDouble() / totalDirect : 0.0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
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
                                  Text(cat['categoryName'] ?? '', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                                  Text('EGP ${_currencyFormat.format((cat['total'] ?? 0).toDouble())}',
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.error),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct.clamp(0.0, 1.0),
                                  backgroundColor: AppColors.cardBorder,
                                  valueColor: const AlwaysStoppedAnimation(AppColors.error),
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('${(pct * 100).toStringAsFixed(1)}% of total • ${cat['count']} expenses',
                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _miniStat(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: color.withValues(alpha: 0.7))),
        Text('EGP ${_currencyFormat.format(value)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _buildExpenseItem(Map<String, dynamic> expense, {bool isAmortized = false}) {
    final typeStr = expense['expenseType'] ?? (isAmortized ? 'AMORTIZED' : 'OPERATING');
    final isItemAmortized = typeStr == 'AMORTIZED' || isAmortized;
    final isItemCapital = typeStr == 'CAPITAL';

    final Color itemColor;
    final IconData itemIcon;
    final String typeLabel;

    if (isItemAmortized) {
      itemColor = AppColors.info;
      itemIcon = LucideIcons.calendarRange;
      typeLabel = 'Amortized';
    } else if (isItemCapital) {
      itemColor = const Color(0xFFD4AF37); // Gold/Amber
      itemIcon = LucideIcons.package;
      typeLabel = 'Capital';
    } else {
      itemColor = AppColors.error;
      itemIcon = LucideIcons.minus;
      typeLabel = 'Operating';
    }

    return GestureDetector(
      onTap: isAmortized ? null : () => _showEditExpenseSheet(expense),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isItemAmortized 
              ? AppColors.info.withValues(alpha: 0.2) 
              : (isItemCapital ? const Color(0xFFD4AF37).withValues(alpha: 0.2) : AppColors.cardBorder),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: itemColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              itemIcon,
              size: 16, color: itemColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense['description'] ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${(expense['category'] as Map?)?['name'] ?? ''}${expense['safe'] != null ? ' • ${(expense['safe'] as Map)['name']}' : ''} • $typeLabel',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isItemAmortized
                    ? 'EGP ${_currencyFormat.format((expense['monthlyAmount'] ?? 0).toDouble())}/mo'
                    : 'EGP ${_currencyFormat.format((expense['amount'] ?? 0).toDouble())}',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: itemColor),
              ),
              if (isItemAmortized)
                Text('Total: ${_currencyFormat.format((expense['totalAmount'] ?? expense['amount'] ?? 0).toDouble())}',
                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
                ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}



