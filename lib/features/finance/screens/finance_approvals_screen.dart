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
import 'package:admin_app/core/services/unread_tracker.dart';

class FinanceApprovalsScreen extends StatefulWidget {
  const FinanceApprovalsScreen({super.key});

  @override
  State<FinanceApprovalsScreen> createState() => _FinanceApprovalsScreenState();
}

class _FinanceApprovalsScreenState extends State<FinanceApprovalsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _withdrawals = [];
  List<Map<String, dynamic>> _safes = [];
  int _pendingCount = 0;
  final _currencyFormat = NumberFormat('#,##0.00', 'en');

  @override
  void initState() {
    super.initState();
    _loadWithdrawals();
  }

  Future<void> _loadWithdrawals() async {
    setState(() => _loading = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final res = await client.get('/api/admin/auth/finance/withdrawals');
      if (mounted) {
        setState(() {
          _withdrawals = List<Map<String, dynamic>>.from(res['withdrawals'] ?? []);
          _safes = List<Map<String, dynamic>>.from(res['safes'] ?? []);
          _pendingCount = res['pendingCount'] ?? 0;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showApproveDialog(Map<String, dynamic> withdrawal) {
    String? selectedSafeId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => Container(
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
                Text('Approve Withdrawal', style: GoogleFonts.playfairDisplay(
                  fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primaryDark,
                )),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Partner', style: GoogleFonts.inter(color: AppColors.textMuted)),
                          Text(withdrawal['investorName'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Amount', style: GoogleFonts.inter(color: AppColors.textMuted)),
                          Text('EGP ${_currencyFormat.format((withdrawal['amount'] ?? 0).toDouble())}',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.error),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Balance', style: GoogleFonts.inter(color: AppColors.textMuted)),
                          Text('EGP ${_currencyFormat.format((withdrawal['investorBalance'] ?? 0).toDouble())}',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.success),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedSafeId,
                  isExpanded: true,
                  icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textMuted),
                  dropdownColor: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(labelText: 'Pay from Safe *'),
                  items: _safes.map((s) => DropdownMenuItem(
                    value: s['id'] as String,
                    child: Text('${s['name']} (${_currencyFormat.format((s['balance'] ?? 0).toDouble())} EGP)', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
                  )).toList(),
                  onChanged: (v) => ss(() => selectedSafeId = v),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(LucideIcons.x, size: 16, color: AppColors.error),
                        label: Text('Reject', style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            final token = context.read<AuthProvider>().token;
                            final client = ApiClient(token: token);
                            await client.put('/api/admin/auth/finance/withdrawals', body: {
                              'withdrawalId': withdrawal['id'],
                              'action': 'reject',
                            });
                            _loadWithdrawals();
                          } catch (_) {}
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(LucideIcons.check, size: 16),
                        label: Text('Approve', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: selectedSafeId == null ? null : () async {
                          Navigator.pop(ctx);
                          try {
                            final token = context.read<AuthProvider>().token;
                            final client = ApiClient(token: token);
                            await client.put('/api/admin/auth/finance/withdrawals', body: {
                              'withdrawalId': withdrawal['id'],
                              'action': 'approve',
                              'safeId': selectedSafeId,
                            });
                            _loadWithdrawals();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(
                                content: const Text('Withdrawal approved ✓'),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'APPROVED': return AppColors.success;
      case 'REJECTED': return AppColors.error;
      case 'PENDING': return AppColors.warning;
      default: return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text('Approvals', style: GoogleFonts.playfairDisplay(
          fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primaryDark,
        )),
        actions: [
          if (_pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                label: Text('$_pendingCount pending', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                backgroundColor: AppColors.warning,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
        ],
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
                      const AppShimmer(width: 44, height: 44, shape: BoxShape.circle),
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
                      const AppShimmer(width: 85, height: 16),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadWithdrawals,
              child: _withdrawals.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 100),
                      Center(child: Column(children: [
                        Icon(LucideIcons.checkCircle2, size: 48, color: AppColors.textMuted.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text('No withdrawal requests', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      ])),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _withdrawals.length,
                      itemBuilder: (ctx, i) {
                        final w = _withdrawals[i];
                        final isPending = w['status'] == 'PENDING';
                        final bool isUnread = isPending && !UnreadTracker.isRead('approval', w['id']);
                        return GestureDetector(
                          onTap: isPending ? () {
                            if (isUnread) {
                              UnreadTracker.markAsRead('approval', w['id']);
                              setState(() {});
                            }
                            _showApproveDialog(w);
                          } : null,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isUnread ? const Color(0xFFF59E0B) : (isPending ? AppColors.warning.withValues(alpha: 0.3) : AppColors.cardBorder)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: _statusColor(w['status']).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(child: Text(
                                    (w['investorName'] ?? 'P')[0].toUpperCase(),
                                    style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: _statusColor(w['status'])),
                                  )),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              w['investorName'] ?? '',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isUnread) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFF59E0B),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Text(_formatDate(w['createdAt']), style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _statusColor(w['status']).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(w['status'], style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: _statusColor(w['status']))),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Text('EGP ${_currencyFormat.format((w['amount'] ?? 0).toDouble())}',
                                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.error),
                                ),
                                if (isPending) ...[
                                  const SizedBox(width: 4),
                                  const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textMuted),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
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


