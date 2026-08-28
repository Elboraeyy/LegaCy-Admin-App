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

class TreasuryScreen extends StatefulWidget {
  const TreasuryScreen({super.key});

  @override
  State<TreasuryScreen> createState() => _TreasuryScreenState();
}

class _TreasuryScreenState extends State<TreasuryScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _safes = [];
  double _totalBalance = 0;
  final _currencyFormat = NumberFormat('#,##0.00', 'en');

  @override
  void initState() {
    super.initState();
    _loadSafes();
  }

  Future<void> _loadSafes() async {
    setState(() => _loading = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final res = await client.get('/api/admin/auth/finance/safes');
      if (mounted) {
        setState(() {
          _safes = List<Map<String, dynamic>>.from(res['safes'] ?? []);
          _totalBalance = (res['totalBalance'] ?? 0).toDouble();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _safeIcon(String type) {
    switch (type) {
      case 'BANK':
        return LucideIcons.building2;
      case 'WALLET':
        return LucideIcons.smartphone;
      case 'CASH':
        return LucideIcons.banknote;
      default:
        return LucideIcons.wallet;
    }
  }

  Color _safeColor(String type) {
    switch (type) {
      case 'BANK':
        return const Color(0xFF3B82F6);
      case 'WALLET':
        return const Color(0xFF8B5CF6);
      case 'CASH':
        return const Color(0xFF059669);
      default:
        return AppColors.accent;
    }
  }

  String _safeLabel(String type) {
    switch (type) {
      case 'BANK':
        return 'Bank Account';
      case 'WALLET':
        return 'E-Wallet';
      case 'CASH':
        return 'Cash';
      default:
        return 'Other';
    }
  }

  void _showAddSafeDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '0');
    String selectedType = 'CASH';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Add New Safe', style: GoogleFonts.playfairDisplay(
                  fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primaryDark,
                )),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Safe Name', hintText: 'e.g. CIB Bank, Cash Drawer'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  isExpanded: true,
                  icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textMuted),
                  dropdownColor: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: ['CASH', 'BANK', 'WALLET', 'OTHER'].map((t) =>
                    DropdownMenuItem(value: t, child: Text(_safeLabel(t), style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary))),
                  ).toList(),
                  onChanged: (v) => setSheetState(() => selectedType = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balanceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Initial Balance', prefixText: 'EGP '),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(LucideIcons.plus, size: 18),
                    label: const Text('Create Safe'),
                    onPressed: () async {
                      if (nameCtrl.text.isEmpty) return;
                      Navigator.pop(ctx);
                      try {
                        final token = context.read<AuthProvider>().token;
                        final client = ApiClient(token: token);
                        await client.post('/api/admin/auth/finance/safes', body: {
                          'action': 'create',
                          'name': nameCtrl.text,
                          'type': selectedType,
                          'balance': double.tryParse(balanceCtrl.text) ?? 0,
                          'description': descCtrl.text.isNotEmpty ? descCtrl.text : null,
                        });
                        _loadSafes();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(
                            content: const Text('Safe created successfully'),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTransferDialog() {
    if (_safes.length < 2) {
      ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(
        content: const Text('You need at least 2 safes to transfer'),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    String? fromId = _safes.first['id'];
    String? toId = _safes.length > 1 ? _safes[1]['id'] : null;
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Internal Transfer', style: GoogleFonts.playfairDisplay(
                  fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primaryDark,
                )),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: fromId,
                  isExpanded: true,
                  icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textMuted),
                  dropdownColor: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(labelText: 'From Safe'),
                  items: _safes.map((s) => DropdownMenuItem(
                    value: s['id'] as String,
                    child: Text('${s['name']} (${_currencyFormat.format(s['balance'])} EGP)', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
                  )).toList(),
                  onChanged: (v) => setSheetState(() => fromId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: toId,
                  isExpanded: true,
                  icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textMuted),
                  dropdownColor: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(labelText: 'To Safe'),
                  items: _safes.map((s) => DropdownMenuItem(
                    value: s['id'] as String,
                    child: Text('${s['name']}', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
                  )).toList(),
                  onChanged: (v) => setSheetState(() => toId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount', prefixText: 'EGP '),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(LucideIcons.arrowLeftRight, size: 18),
                    label: const Text('Transfer'),
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text) ?? 0;
                      if (fromId == toId || amount <= 0) return;
                      Navigator.pop(ctx);
                      try {
                        final token = context.read<AuthProvider>().token;
                        final client = ApiClient(token: token);
                        await client.post('/api/admin/auth/finance/safes', body: {
                          'action': 'transfer',
                          'fromSafeId': fromId,
                          'toSafeId': toId,
                          'amount': amount,
                          'description': descCtrl.text.isNotEmpty ? descCtrl.text : null,
                        });
                        _loadSafes();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(
                            content: const Text('Transfer completed'),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text('Treasury', style: GoogleFonts.playfairDisplay(
          fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primaryDark,
        )),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.arrowLeftRight, size: 20),
            onPressed: _showTransferDialog,
            tooltip: 'Transfer',
          ),
          IconButton(
            icon: const Icon(LucideIcons.plus, size: 20),
            onPressed: _showAddSafeDialog,
            tooltip: 'Add Safe',
          ),
        ],
      ),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                const AppShimmer(width: double.infinity, height: 140, borderRadius: 24),
                const SizedBox(height: 24),
                ...List.generate(3, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
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
                              AppShimmer(width: 120, height: 14),
                              SizedBox(height: 6),
                              AppShimmer(width: 80, height: 10),
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
          : RefreshIndicator(
              onRefresh: _loadSafes,
              color: AppColors.primaryDark,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  // Total Balance Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryDark, Color(0xFF1E5C56)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryDark.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(LucideIcons.landmark, color: AppColors.accentLight, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Text('Total Balance', style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white70,
                            )),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'EGP ${_currencyFormat.format(_totalBalance)}',
                          style: GoogleFonts.inter(
                            fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_safes.length} active safes',
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Safes list
                  if (_safes.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          Icon(LucideIcons.landmark, size: 48, color: AppColors.textMuted.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text('No safes yet', style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary,
                          )),
                          const SizedBox(height: 8),
                          Text('Add your first safe to start tracking money', style: GoogleFonts.inter(
                            fontSize: 13, color: AppColors.textMuted,
                          )),
                        ],
                      ),
                    )
                  else
                    ..._safes.map((safe) => _buildSafeCard(safe)),
                ],
              ),
            ),
    );
  }

  Widget _buildSafeCard(Map<String, dynamic> safe) {
    final type = safe['type'] ?? 'CASH';
    final color = _safeColor(type);
    final balance = (safe['balance'] ?? 0).toDouble();
    final transactions = List<Map<String, dynamic>>.from(safe['recentTransactions'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardBorder.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_safeIcon(type), size: 20, color: color),
          ),
          title: Text(safe['name'] ?? '', style: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
          )),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                'EGP ${_currencyFormat.format(balance)}',
                style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: balance >= 0 ? AppColors.success : AppColors.error,
                ),
              ),
              Text(_safeLabel(type), style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.textMuted,
              )),
            ],
          ),
          children: [
            if (transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No transactions yet', style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textMuted,
                )),
              )
            else
              ...transactions.take(5).map((tx) {
                final isCredit = tx['type'] == 'CREDIT' || tx['type'] == 'TRANSFER_IN';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: (isCredit ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isCredit ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
                          size: 14,
                          color: isCredit ? AppColors.success : AppColors.error,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx['description'] ?? tx['type'],
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _formatDate(tx['createdAt']),
                              style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${isCredit ? "+" : "-"}${_currencyFormat.format((tx['amount'] ?? 0).toDouble())}',
                        style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: isCredit ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return DateFormat('dd MMM, HH:mm').format(dt.toLocal());
  }
}



