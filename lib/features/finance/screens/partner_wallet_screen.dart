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

class PartnerWalletScreen extends StatefulWidget {
  const PartnerWalletScreen({super.key});

  @override
  State<PartnerWalletScreen> createState() => _PartnerWalletScreenState();
}

class _PartnerWalletScreenState extends State<PartnerWalletScreen> {
  bool _loading = true;
  bool _isPartner = false;
  Map<String, dynamic> _wallet = {};
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _partners = [];
  final _currencyFormat = NumberFormat('#,##0.00', 'en');

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet({String? investorId}) async {
    setState(() => _loading = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final url = investorId != null
          ? '/api/admin/auth/finance/wallet?investorId=$investorId'
          : '/api/admin/auth/finance/wallet';
      final res = await client.get(url);
      if (mounted) {
        setState(() {
          _isPartner = res['isPartner'] ?? false;
          if (_isPartner) {
            _wallet = Map<String, dynamic>.from(res['wallet'] ?? {});
            _history = List<Map<String, dynamic>>.from(res['history'] ?? []);
          } else {
            _partners = List<Map<String, dynamic>>.from(res['partners'] ?? []);
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showWithdrawDialog() {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
                child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.textMuted.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text('Request Withdrawal', style: GoogleFonts.playfairDisplay(
                fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primaryDark,
              )),
              const SizedBox(height: 8),
              Text('Available: EGP ${_currencyFormat.format((_wallet['walletBalance'] ?? 0).toDouble())}',
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.success, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount', prefixText: 'EGP '),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(LucideIcons.arrowUpRight, size: 18),
                  label: const Text('Submit Request'),
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text) ?? 0;
                    if (amount <= 0) return;
                    Navigator.pop(ctx);
                    try {
                      final token = context.read<AuthProvider>().token;
                      final client = ApiClient(token: token);
                      await client.post('/api/admin/auth/finance/wallet', body: {
                        'action': 'withdraw',
                        'amount': amount,
                        'notes': notesCtrl.text.isNotEmpty ? notesCtrl.text : null,
                        if (_wallet['investorId'] != null) 'investorId': _wallet['investorId'],
                      });
                      _loadWallet(investorId: _wallet['investorId']);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(
                          content: const Text('Withdrawal request submitted'),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text('My Wallet', style: GoogleFonts.playfairDisplay(
          fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primaryDark,
        )),
      ),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                const AppShimmer(width: double.infinity, height: 160, borderRadius: 24),
                const SizedBox(height: 16),
                const AppShimmer(width: double.infinity, height: 48, borderRadius: 14),
                const SizedBox(height: 24),
                const AppShimmer(width: 150, height: 14),
                const SizedBox(height: 12),
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
                        const AppShimmer(width: 36, height: 36, borderRadius: 10),
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
                        const AppShimmer(width: 70, height: 16),
                      ],
                    ),
                  ),
                )),
              ],
            )
          : _isPartner ? _buildWalletView() : _buildPartnersList(),
    );
  }

  Widget _buildPartnersList() {
    return RefreshIndicator(
      onRefresh: _loadWallet,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Text('ALL PARTNERS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1)),
          const SizedBox(height: 12),
          ..._partners.map((p) => GestureDetector(
            onTap: () => _loadWallet(investorId: p['id']),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: Text(
                      (p['name'] ?? 'P')[0].toUpperCase(),
                      style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.accent),
                    )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['name'] ?? '', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                        Text('Share: ${((p['currentShare'] ?? 0).toDouble() * 100).toStringAsFixed(1)}%',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('EGP ${_currencyFormat.format((p['walletBalance'] ?? 0).toDouble())}',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.success),
                      ),
                      Text('balance', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                    ],
                  ),
                  const SizedBox(width: 4),
                  const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textMuted),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildWalletView() {
    final balance = (_wallet['walletBalance'] ?? 0).toDouble();
    final earned = (_wallet['totalEarnings'] ?? 0).toDouble();
    final withdrawn = (_wallet['totalWithdrawn'] ?? 0).toDouble();
    final share = ((_wallet['currentShare'] ?? 0).toDouble() * 100);

    return RefreshIndicator(
      onRefresh: () => _loadWallet(investorId: _wallet['investorId']),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // Balance card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF047857)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: AppColors.success.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_wallet['name'] ?? '', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${share.toStringAsFixed(1)}%', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Available Balance', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
                Text('EGP ${_currencyFormat.format(balance)}',
                  style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _walletStat('Total Earned', earned),
                    const SizedBox(width: 24),
                    _walletStat('Withdrawn', withdrawn),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Withdraw button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              icon: const Icon(LucideIcons.arrowUpRight, size: 18),
              label: Text('Request Withdrawal', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side: const BorderSide(color: AppColors.primaryDark),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _showWithdrawDialog,
            ),
          ),
          const SizedBox(height: 24),
          // History
          Text('TRANSACTION HISTORY', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1)),
          const SizedBox(height: 12),
          if (_history.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text('No transactions yet', style: GoogleFonts.inter(color: AppColors.textMuted))),
            )
          else
            ..._history.map((tx) {
              final amount = (tx['amount'] ?? 0).toDouble();
              final isPositive = amount > 0;
              final status = tx['status'] ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: (isPositive ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isPositive ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
                        size: 16, color: isPositive ? AppColors.success : AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx['description'] ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                          Row(
                            children: [
                              Text(_formatDate(tx['date']), style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                              if (status == 'PENDING') ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('Pending', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.warning)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isPositive ? "+" : ""}${_currencyFormat.format(amount)}',
                      style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: isPositive ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _walletStat(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.white60)),
        Text('EGP ${_currencyFormat.format(value)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return DateFormat('dd MMM yyyy').format(dt.toLocal());
  }
}
