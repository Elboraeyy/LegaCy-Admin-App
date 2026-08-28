import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:admin_app/core/widgets/app_shimmer.dart';

class CategoryDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> category;
  final int initialMonth;
  final int initialYear;

  const CategoryDetailsScreen({
    super.key,
    required this.category,
    required this.initialMonth,
    required this.initialYear,
  });

  @override
  State<CategoryDetailsScreen> createState() => _CategoryDetailsScreenState();
}

class _CategoryDetailsScreenState extends State<CategoryDetailsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _amortized = [];
  Map<String, dynamic> _stats = {};
  late int _month;
  late int _year;
  final _currencyFormat = NumberFormat('#,##0.00', 'en');

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
    _year = widget.initialYear;
    _loadCategoryExpenses();
  }

  Future<void> _loadCategoryExpenses() async {
    setState(() => _loading = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final categoryId = widget.category['id'];
      final res = await client.get('/api/admin/auth/finance/expenses?month=$_month&year=$_year&categoryId=$categoryId');
      if (mounted) {
        setState(() {
          _expenses = List<Map<String, dynamic>>.from(res['expenses'] ?? []);
          _amortized = List<Map<String, dynamic>>.from(res['amortizedExpenses'] ?? []);
          _stats = Map<String, dynamic>.from(res['stats'] ?? {});
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
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
                      _loadCategoryExpenses();
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
    final totalDirect = (_stats['totalDirectExpenses'] ?? 0).toDouble();
    final totalAmort = (_stats['totalAmortizedThisMonth'] ?? 0).toDouble();
    final totalCapital = (_stats['totalCapitalExpenses'] ?? 0).toDouble();
    final totalAll = (_stats['totalExpensesThisMonth'] ?? 0).toDouble();
    final subcats = List<Map<String, dynamic>>.from(widget.category['children'] ?? []);

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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.category['name'] ?? 'Category Details', style: GoogleFonts.playfairDisplay(
          fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primaryDark,
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
      ),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                const AppShimmer(width: double.infinity, height: 130, borderRadius: 20),
                const SizedBox(height: 24),
                const AppShimmer(width: 120, height: 14),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: List.generate(3, (i) => const AppShimmer(width: 100, height: 40, borderRadius: 10)),
                ),
                const SizedBox(height: 24),
                const AppShimmer(width: 150, height: 14),
                const SizedBox(height: 10),
                ...List.generate(4, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const AppShimmer(width: 38, height: 38, borderRadius: 10),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              AppShimmer(width: 120, height: 14),
                              SizedBox(height: 6),
                              AppShimmer(width: 180, height: 10),
                            ],
                          ),
                        ),
                        const AppShimmer(width: 80, height: 16),
                      ],
                    ),
                  ),
                )),
              ],
            )
          : RefreshIndicator(
              onRefresh: _loadCategoryExpenses,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // Summary Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primaryDark, AppColors.primaryDark.withValues(alpha: 0.85)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryDark.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('MMMM yyyy').format(DateTime(_year, _month)),
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'EGP ${_currencyFormat.format(totalAll)}',
                          style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
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
                  const SizedBox(height: 24),

                  // Subcategories Info
                  if (subcats.isNotEmpty) ...[
                    Text('SUBCATEGORIES', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: subcats.map((sub) {
                        // Count how many expenses are under this subcategory in this month
                        final count = _expenses.where((e) => (e['subcategory'] as Map?)?['id'] == sub['id']).length;
                        final amount = _expenses
                            .where((e) => (e['subcategory'] as Map?)?['id'] == sub['id'])
                            .fold(0.0, (sum, e) => sum + (e['amount'] ?? 0).toDouble());

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                sub['name'] ?? '',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$count exp • EGP ${_currencyFormat.format(amount)}',
                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Expenses list
                  Text('EXPENSE TRANSACTIONS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1)),
                  const SizedBox(height: 10),
                  
                  if (_amortized.isNotEmpty) ...[
                    ..._amortized.map((e) => _buildExpenseItem(e, isAmortized: true)),
                  ],

                  if (_expenses.isEmpty && _amortized.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No expenses found for this month',
                          style: GoogleFonts.inter(color: AppColors.textMuted),
                        ),
                      ),
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
    );
  }

  Widget _miniStat(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: color.withValues(alpha: 0.7))),
        const SizedBox(height: 2),
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

    final dateStr = expense['date'] != null 
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(expense['date']).toLocal())
        : '';
    final subcatName = (expense['subcategory'] as Map?)?['name'] ?? '';
    final safeName = (expense['safe'] as Map?)?['name'] ?? '';

    return Container(
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
                Text(
                  expense['description'] ?? '', 
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600), 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  (subcatName.isNotEmpty ? '$subcatName' : 'Main Category') + 
                  (safeName.isNotEmpty ? ' • $safeName' : '') + 
                  (dateStr.isNotEmpty ? ' • $dateStr' : '') +
                  ' • $typeLabel',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
                Text(
                  'Total: ${_currencyFormat.format((expense['totalAmount'] ?? expense['amount'] ?? 0).toDouble())}',
                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
