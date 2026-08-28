import 'package:admin_app/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:admin_app/core/widgets/app_shimmer.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _inventory = [];
  List<dynamic> _filteredInventory = [];
  Map<String, dynamic> _summary = {};
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'all'; // all, low, out

  @override
  void initState() {
    super.initState();
    _loadInventory();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final data = await client.get('/api/admin/auth/inventory');

      if (mounted) {
        setState(() {
          _inventory = data['inventory'] ?? [];
          _summary = data['summary'] ?? {};
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredInventory = _inventory.where((item) {
        final name = item['productName']?.toString().toLowerCase() ?? '';
        final sku = item['sku']?.toString().toLowerCase() ?? '';
        final matchSearch = name.contains(query) || sku.contains(query);
        final isLow = item['isLowStock'] == true;
        final isOut = item['isOutOfStock'] == true;
        final isInStock = !isLow && !isOut;
        
        if (_filter == 'low') return matchSearch && isLow;
        if (_filter == 'out') return matchSearch && isOut;
        if (_filter == 'instock') return matchSearch && isInStock;
        return matchSearch;
      }).toList();

      if (_filter == 'all') {
        _filteredInventory.sort((a, b) {
          int scoreA = (a['isOutOfStock'] == true) ? 2 : (a['isLowStock'] == true ? 1 : 0);
          int scoreB = (b['isOutOfStock'] == true) ? 2 : (b['isLowStock'] == true ? 1 : 0);
          return scoreA.compareTo(scoreB);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Inventory', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.arrowLeft, color: AppColors.primaryDark), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: List.generate(3, (i) => Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: i < 2 ? 10 : 0),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        children: const [
                          AppShimmer(width: 20, height: 20),
                          SizedBox(height: 8),
                          AppShimmer(width: 30, height: 20),
                          SizedBox(height: 4),
                          AppShimmer(width: 60, height: 10),
                        ],
                      ),
                    ),
                  )),
                ),
                const SizedBox(height: 16),
                const AppShimmer(width: double.infinity, height: 48, borderRadius: 16),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: List.generate(3, (i) => Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 70, height: 32,
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.cardBorder)),
                        )),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...List.generate(4, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
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
                              AppShimmer(width: 150, height: 14),
                              SizedBox(height: 6),
                              AppShimmer(width: 180, height: 10),
                            ],
                          ),
                        ),
                        const AppShimmer(width: 30, height: 20),
                      ],
                    ),
                  ),
                )),
              ],
            )
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(LucideIcons.alertCircle, size: 48, color: AppColors.error), const SizedBox(height: 16), Text(_error!, style: GoogleFonts.inter(color: AppColors.error)), const SizedBox(height: 16), ElevatedButton(onPressed: _loadInventory, child: const Text('Retry'))]))
              : _buildStockTab(),
    );
  }

  Widget _buildStockTab() {
    return RefreshIndicator(
      onRefresh: _loadInventory,
      color: AppColors.primaryDark,
      child: CustomScrollView(
        slivers: [
          // Summary Cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: _buildSummaryCard('Total Items', '${_summary['totalItems'] ?? 0}', LucideIcons.package, const Color(0xFF3B82F6))),
                  const SizedBox(width: 10),
                  Expanded(child: _buildSummaryCard('Low Stock', '${_summary['lowStock'] ?? 0}', LucideIcons.alertTriangle, const Color(0xFFF59E0B))),
                  const SizedBox(width: 10),
                  Expanded(child: _buildSummaryCard('Out of Stock', '${_summary['outOfStock'] ?? 0}', LucideIcons.xCircle, const Color(0xFFEF4444))),
                ],
              ),
            ),
          ),

          // Search + Filter
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by product or SKU...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                    prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.textMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildChip('All', 'all'),
                          const SizedBox(width: 8),
                          _buildChip('In Stock', 'instock'),
                          const SizedBox(width: 8),
                          _buildChip('Low Stock', 'low'),
                          const SizedBox(width: 8),
                          _buildChip('Out of Stock', 'out'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${_filteredInventory.length} items', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
          ),

          // Inventory List
          _filteredInventory.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppColors.primaryDark.withValues(alpha: 0.05), shape: BoxShape.circle), child: const Icon(LucideIcons.package, size: 48, color: AppColors.primaryDark)),
                      const SizedBox(height: 24),
                      Text('No inventory found', style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                    ]),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _filteredInventory[index];
                      final isLow = item['isLowStock'] == true;
                      final isOut = item['isOutOfStock'] == true;
                      final statusColor = isOut ? AppColors.error : isLow ? AppColors.warning : AppColors.success;

                      return GestureDetector(
                        onTap: () => _showAdjustmentDialog(item),
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isOut ? AppColors.error.withValues(alpha: 0.3) : isLow ? AppColors.warning.withValues(alpha: 0.3) : AppColors.cardBorder),
                            boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                child: Icon(isOut ? LucideIcons.xCircle : isLow ? LucideIcons.alertTriangle : LucideIcons.checkCircle2, size: 20, color: statusColor),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['productName'] ?? '', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text('SKU: ${item['sku']} • ${item['warehouseName']}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${item['available']}', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: statusColor)),
                                  Text('min: ${item['minStock']}', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _filteredInventory.length,
                  ),
                ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  void _showAdjustmentDialog(Map<String, dynamic> item) {
    final availableCtrl = TextEditingController(text: item['available'].toString());
    final minStockCtrl = TextEditingController(text: item['minStock'].toString());
    final reasonCtrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) {
        return Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textMuted.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Adjust Stock', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
              const SizedBox(height: 4),
              Text(item['productName'] ?? '', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
              Text('SKU: ${item['sku']} • ${item['warehouseName']}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: _buildInput('Available Stock', availableCtrl, LucideIcons.package, isNumber: true),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInput('Min Alert Level', minStockCtrl, LucideIcons.bellRing, isNumber: true),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildInput('Adjustment Reason (Optional)', reasonCtrl, LucideIcons.stickyNote),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    setModalState(() => isSaving = true);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final token = context.read<AuthProvider>().token;
                      final client = ApiClient(token: token);
                      await client.post('/api/admin/auth/inventory', body: {
                        'id': item['id'],
                        'available': int.tryParse(availableCtrl.text) ?? item['available'],
                        'minStock': int.tryParse(minStockCtrl.text) ?? item['minStock'],
                        'reason': reasonCtrl.text.trim(),
                      });
                      if (!mounted) return;
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadInventory();
                      if (!mounted) return;
                      messenger.showAppToast(AppToast.snackBar(content: Text('Stock updated successfully'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
                    } catch (e) {
                      setModalState(() => isSaving = false);
                      messenger.showAppToast(AppToast.snackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                  child: isSaving 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Update Inventory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, IconData icon, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
            filled: true, fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }




  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () { setState(() => _filter = value); _applyFilter(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primaryDark : AppColors.cardBorder),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }
}
