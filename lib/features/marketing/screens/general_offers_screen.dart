import 'package:admin_app/core/widgets/app_toast.dart';
import 'package:admin_app/core/widgets/app_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:intl/intl.dart';

class GeneralOffersScreen extends StatefulWidget {
  const GeneralOffersScreen({super.key});
  @override
  State<GeneralOffersScreen> createState() => _GeneralOffersScreenState();
}

class _GeneralOffersScreenState extends State<GeneralOffersScreen> {
  static const _accent = Color(0xFF10B981);
  List<dynamic> _offers = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  ApiClient get _client => ApiClient(token: context.read<AuthProvider>().token);

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await _client.get('/api/admin/auth/offers');
      if (mounted) setState(() { _offers = data['offers'] as List<dynamic>; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleActive(String id, bool isActive) async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    try {
      await _client.put('/api/admin/auth/offers/$id', body: { 'isActive': !isActive });
      _load();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(content: Text('Error: $e'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _deleteOffer(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Delete Offer?', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
        content: Text('This action cannot be undone.', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textMuted, fontWeight: FontWeight.w600))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    try {
      await _client.delete('/api/admin/auth/offers/$id');
      if (mounted) ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(content: Text('Offer deleted'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
      _load();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(content: Text('Error: $e'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
    }
  }

  Future<List<Map<String, String>>> _fetchTargets(String type) async {
    try {
      if (type == 'PRODUCT') {
        final data = await _client.get('/api/admin/auth/products?limit=500');
        return (data['products'] as List).map<Map<String, String>>((p) => {'id': p['id'].toString(), 'name': p['name']?.toString() ?? ''}).toList();
      } else if (type == 'CATEGORY') {
        final data = await _client.get('/api/admin/auth/categories');
        final list = data['categories'] ?? data;
        return (list as List).map<Map<String, String>>((c) => {'id': c['id'].toString(), 'name': c['name']?.toString() ?? ''}).toList();
      } else if (type == 'BRAND') {
        final data = await _client.get('/api/admin/auth/brands');
        final list = data['brands'] ?? data;
        return (list as List).map<Map<String, String>>((b) => {'id': b['id'].toString(), 'name': b['name']?.toString() ?? ''}).toList();
      } else if (type == 'MATERIAL') {
        final data = await _client.get('/api/admin/auth/materials');
        final list = data['materials'] ?? data;
        return (list as List).map<Map<String, String>>((m) => {'id': m['id'].toString(), 'name': m['name']?.toString() ?? ''}).toList();
      }
    } catch (_) {}
    return [];
  }

  void _showCreateEditDialog({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    final valueCtrl = TextEditingController(text: existing?['discountValue']?.toString() ?? '');
    final priorityCtrl = TextEditingController(text: (existing?['priority'] ?? 0).toString());
    String offerType = existing?['offerType'] ?? 'ALL_PRODUCTS';
    String discountType = existing?['discountType'] ?? 'PERCENTAGE';
    DateTime? startDate = existing?['startDate'] != null ? DateTime.tryParse(existing!['startDate'])?.toLocal() : DateTime.now();
    DateTime? endDate = existing?['endDate'] != null ? DateTime.tryParse(existing!['endDate'])?.toLocal() : null;
    bool isActive = existing?['isActive'] ?? true;
    String? targetId = existing?['targetId'];
    String? targetName = existing?['targetName'];
    List<Map<String, String>> targetOptions = [];
    bool loadingTargets = false;
    bool _isInit = false;

    bool _hasChanges() {
      if (!isEdit) return nameCtrl.text.isNotEmpty && valueCtrl.text.isNotEmpty;
      return nameCtrl.text != (existing['name'] ?? '') ||
             descCtrl.text != (existing['description'] ?? '') ||
             valueCtrl.text != (existing['discountValue']?.toString() ?? '') ||
             priorityCtrl.text != (existing['priority'] ?? 0).toString() ||
             offerType != (existing['offerType'] ?? 'ALL_PRODUCTS') ||
             discountType != (existing['discountType'] ?? 'PERCENTAGE') ||
             isActive != (existing['isActive'] ?? true) ||
             targetId != existing['targetId'];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> pickDate(bool isStart) async {
            final initial = isStart ? (startDate ?? DateTime.now()) : (endDate ?? DateTime.now().add(const Duration(days: 7)));
            final date = await showDatePicker(
              context: ctx,
              initialDate: initial,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: _GeneralOffersScreenState._accent)), child: child!),
            );
            if (date != null) setModalState(() { if (isStart) startDate = date; else endDate = date; });
          }

          if (!_isInit) {
            _isInit = true;
            if (offerType != 'ALL_PRODUCTS') {
              loadingTargets = true;
              _fetchTargets(offerType).then((items) {
                setModalState(() {
                  targetOptions = items;
                  loadingTargets = false;
                  if (targetId != null && !items.any((e) => e['id'] == targetId)) {
                    if (targetName != null) {
                       targetOptions.add({'id': targetId!, 'name': targetName!});
                    } else {
                       targetId = null;
                    }
                  }
                });
              });
            }
          }

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.9,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isEdit ? 'Edit Offer' : 'New Offer', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                      IconButton(icon: const Icon(LucideIcons.x), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                // Form
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _formField('Offer Name', nameCtrl, 'e.g. Summer Sale 20% OFF', LucideIcons.tag),
                      const SizedBox(height: 16),
                      _formField('Description (optional)', descCtrl, 'Describe the offer...', LucideIcons.fileText),
                      const SizedBox(height: 16),

                      // Offer Type
                      Text('Target Type', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [
                          _buildChip('🌐 Storewide', 'ALL_PRODUCTS', offerType, (v) {
                            setModalState(() { offerType = v; targetId = null; targetName = null; targetOptions = []; });
                          }),
                          _buildChip('🛍️ Product', 'PRODUCT', offerType, (v) async {
                            setModalState(() { offerType = v; targetId = null; targetName = null; loadingTargets = true; });
                            final items = await _fetchTargets(v);
                            setModalState(() { targetOptions = items; loadingTargets = false; });
                          }),
                          _buildChip('📂 Category', 'CATEGORY', offerType, (v) async {
                            setModalState(() { offerType = v; targetId = null; targetName = null; loadingTargets = true; });
                            final items = await _fetchTargets(v);
                            setModalState(() { targetOptions = items; loadingTargets = false; });
                          }),
                          _buildChip('🏢 Brand', 'BRAND', offerType, (v) async {
                            setModalState(() { offerType = v; targetId = null; targetName = null; loadingTargets = true; });
                            final items = await _fetchTargets(v);
                            setModalState(() { targetOptions = items; loadingTargets = false; });
                          }),
                          _buildChip('💎 Material', 'MATERIAL', offerType, (v) async {
                            setModalState(() { offerType = v; targetId = null; targetName = null; loadingTargets = true; });
                            final items = await _fetchTargets(v);
                            setModalState(() { targetOptions = items; loadingTargets = false; });
                          }),
                        ],
                      ),
                      // Target Selector
                      if (offerType != 'ALL_PRODUCTS') ...[
                        const SizedBox(height: 12),
                        Text(
                          offerType == 'PRODUCT' ? 'Select Product' : offerType == 'CATEGORY' ? 'Select Category' : offerType == 'BRAND' ? 'Select Brand' : 'Select Material',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        loadingTargets
                            ? Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                                child: Row(children: [
                                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _GeneralOffersScreenState._accent)),
                                  const SizedBox(width: 12),
                                  Text('Loading...', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                                ]),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.cardBorder),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: targetId,
                                    isExpanded: true,
                                    icon: const Icon(LucideIcons.chevronDown, size: 18, color: AppColors.textMuted),
                                    borderRadius: BorderRadius.circular(16),
                                    elevation: 8,
                                    hint: Row(
                                      children: [
                                        Icon(offerType == 'PRODUCT' ? LucideIcons.package : offerType == 'CATEGORY' ? LucideIcons.layoutGrid : offerType == 'BRAND' ? LucideIcons.building2 : LucideIcons.gem, size: 16, color: AppColors.textMuted),
                                        const SizedBox(width: 10),
                                        Text('Choose...', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                                      ],
                                    ),
                                    items: targetOptions.map((t) => DropdownMenuItem(
                                      value: t['id'],
                                      child: Text(t['name'] ?? '', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                                    )).toList(),
                                    onChanged: (v) {
                                      final match = targetOptions.firstWhere((t) => t['id'] == v, orElse: () => {});
                                      setModalState(() { targetId = v; targetName = match['name']; });
                                    },
                                  ),
                                ),
                              ),
                      ],
                      // Discount Type
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Discount Type', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: discountType,
                                isExpanded: true,
                                icon: const Icon(LucideIcons.chevronDown, size: 18, color: AppColors.textMuted),
                                borderRadius: BorderRadius.circular(16),
                                elevation: 8,
                                items: [
                                  DropdownMenuItem(value: 'PERCENTAGE', child: Row(children: [
                                    const Icon(LucideIcons.percent, size: 16, color: _GeneralOffersScreenState._accent),
                                    const SizedBox(width: 10),
                                    Text('Percentage (%)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                                  ])),
                                  DropdownMenuItem(value: 'FIXED', child: Row(children: [
                                    const Icon(LucideIcons.banknote, size: 16, color: _GeneralOffersScreenState._accent),
                                    const SizedBox(width: 10),
                                    Text('Fixed (EGP)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                                  ])),
                                ],
                                onChanged: (v) => setModalState(() => discountType = v!),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Value
                      _formField('Value', valueCtrl, discountType == 'PERCENTAGE' ? '20' : '100', discountType == 'PERCENTAGE' ? LucideIcons.percent : LucideIcons.banknote, isNumber: true),

                      _formField('Priority', priorityCtrl, '0', LucideIcons.arrowUpDown, isNumber: true),
                      const SizedBox(height: 4),
                      Text('Higher priority offers apply first', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                      const SizedBox(height: 16),

                      // Dates
                      Text('Duration', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => pickDate(true),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.calendarDays, size: 16, color: _GeneralOffersScreenState._accent),
                                    const SizedBox(width: 8),
                                    Text(startDate != null ? DateFormat('MMM d, yyyy').format(startDate!) : 'Start', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => pickDate(false),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.calendarOff, size: 16, color: _GeneralOffersScreenState._accent),
                                    const SizedBox(width: 8),
                                    Text(endDate != null ? DateFormat('MMM d, yyyy').format(endDate!) : 'No end', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Active Switch
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Active', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            Switch(value: isActive, onChanged: (v) => setModalState(() => isActive = v), activeTrackColor: _GeneralOffersScreenState._accent),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _hasChanges() ? () async {
                            if (nameCtrl.text.isEmpty || valueCtrl.text.isEmpty) {
                              ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(content: Text('Name and value are required'), behavior: SnackBarBehavior.floating));
                              return;
                            }
                            Navigator.pop(ctx);
                            setState(() => _isLoading = true);
                            try {
                              final body = {
                                'name': nameCtrl.text,
                                'description': descCtrl.text.isNotEmpty ? descCtrl.text : null,
                                'offerType': offerType,
                                'discountType': discountType,
                                'discountValue': valueCtrl.text,
                                'priority': int.tryParse(priorityCtrl.text) ?? 0,
                                'isActive': isActive,
                                'startDate': startDate?.toUtc().toIso8601String(),
                                'endDate': endDate?.toUtc().toIso8601String(),
                                if (targetId != null) 'targetId': targetId,
                                if (targetName != null) 'targetName': targetName,
                              };
                              if (isEdit) {
                                await _client.put('/api/admin/auth/offers/${existing['id']}', body: body);
                              } else {
                                await _client.post('/api/admin/auth/offers', body: body);
                              }
                              if (mounted) ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(content: Text(isEdit ? 'Offer updated' : 'Offer created'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
                              _load();
                            } catch (e) {
                              if (mounted) setState(() => _isLoading = false);
                              if (mounted) ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(content: Text('Error: $e'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
                            }
                          } : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent, 
                            foregroundColor: Colors.white, 
                            padding: const EdgeInsets.symmetric(vertical: 16), 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), 
                            elevation: 0,
                            disabledBackgroundColor: Colors.grey.shade300,
                            disabledForegroundColor: Colors.grey.shade500,
                          ),
                          child: Text(isEdit ? 'Save Changes' : 'Create Offer', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _formField(String label, TextEditingController ctrl, String hint, IconData icon, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          onChanged: (_) {
            if (context.mounted) {
              final state = context.findAncestorStateOfType<State<StatefulBuilder>>();
              if (state != null) {
                // ignore: invalid_use_of_protected_member
                state.setState(() {});
              }
            }
          },
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
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

  Widget _buildChip(String label, String value, String current, Function(String) onTap) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _accent.withValues(alpha: 0.15) : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _accent : AppColors.cardBorder, width: selected ? 2 : 1),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? _accent : AppColors.textSecondary)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(LucideIcons.tag, color: _accent),
            const SizedBox(width: 8),
            Text('Product Offers', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
          ],
        ),
        backgroundColor: AppColors.surface, surfaceTintColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.arrowLeft, color: AppColors.primaryDark), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppShimmer(width: 150, height: 16),
                                    SizedBox(height: 6),
                                    AppShimmer(width: 220, height: 12),
                                  ],
                                ),
                                AppShimmer(width: 44, height: 24, borderRadius: 12),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: const [
                                AppShimmer(width: 90, height: 24, borderRadius: 8),
                                SizedBox(width: 8),
                                AppShimmer(width: 70, height: 24, borderRadius: 8),
                                SizedBox(width: 8),
                                AppShimmer(width: 80, height: 24, borderRadius: 8),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.5),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                          border: Border(top: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.5))),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Row(
                              children: [
                                AppShimmer(width: 12, height: 12, borderRadius: 2),
                                SizedBox(width: 8),
                                AppShimmer(width: 140, height: 12),
                              ],
                            ),
                            Row(
                              children: [
                                AppShimmer(width: 28, height: 28, borderRadius: 8),
                                SizedBox(width: 8),
                                AppShimmer(width: 28, height: 28, borderRadius: 8),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : _offers.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: _accent,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _offers.length,
                    itemBuilder: (context, index) => _buildOfferCard(_offers[index]),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () { HapticFeedback.lightImpact(); _showCreateEditDialog(); },
        backgroundColor: _accent,
        icon: const Icon(LucideIcons.plus, color: Colors.white),
        label: Text('New Offer', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _accent.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(LucideIcons.tag, size: 48, color: _accent)),
            const SizedBox(height: 20),
            Text('No Active Offers', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
            const SizedBox(height: 8),
            Text('Create your first product offer', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> o) {
    final bool isActive = o['isActive'] == true;
    final String type = o['offerType'] ?? 'ALL_PRODUCTS';
    final String discountType = o['discountType'] ?? 'PERCENTAGE';

    String typeLabel;
    switch (type) {
      case 'ALL_PRODUCTS': typeLabel = '🌐 Storewide'; break;
      case 'PRODUCT': typeLabel = '🛍️ Product'; break;
      case 'CATEGORY': typeLabel = '📂 Category'; break;
      case 'BRAND': typeLabel = '🏢 Brand'; break;
      case 'MATERIAL': typeLabel = '💎 Material'; break;
      default: typeLabel = type;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? _accent.withValues(alpha: 0.4) : AppColors.cardBorder),
        boxShadow: [BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o['name'] ?? 'Offer', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                          if (o['description'] != null && (o['description'] as String).isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(o['description'], style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                    ),
                    Switch(value: isActive, onChanged: (v) => _toggleActive(o['id'], isActive), activeTrackColor: _accent),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    _infoBadge(typeLabel, _accent),
                    if (o['targetName'] != null && (o['targetName'] as String).isNotEmpty)
                      _infoBadge(o['targetName'], const Color(0xFF6366F1)),
                    _infoBadge(
                      discountType == 'PERCENTAGE' ? '${o['discountValue']}% OFF' : 'EGP ${o['discountValue']} OFF',
                      const Color(0xFFEF4444),
                    ),
                    if (o['priority'] != null && o['priority'] != 0) _infoBadge('Priority: ${o['priority']}', const Color(0xFF8B5CF6)),
                  ],
                ),
              ],
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              border: Border(top: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.5))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.calendar, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      o['startDate'] != null ? 'Starts: ${_formatDate(o['startDate'])}' : 'Always',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                    ),
                    if (o['endDate'] != null) ...[
                      const SizedBox(width: 8),
                      Text('→ ${_formatDate(o['endDate'])}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showCreateEditDialog(existing: o),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(LucideIcons.edit2, size: 16, color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _deleteOffer(o['id']),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Icon(LucideIcons.trash2, size: 16, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  String _formatDate(String? d) {
    if (d == null) return '';
    final dt = DateTime.tryParse(d);
    if (dt == null) return d;
    return DateFormat('MMM d, yyyy').format(dt);
  }
}

