import 'package:admin_app/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:admin_app/core/widgets/app_shimmer.dart';
import 'package:admin_app/core/services/unread_tracker.dart';

class ReviewsListScreen extends StatefulWidget {
  const ReviewsListScreen({super.key});
  @override
  State<ReviewsListScreen> createState() => _ReviewsListScreenState();
}

class _ReviewsListScreenState extends State<ReviewsListScreen> {
  List<dynamic> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final data = await client.get('/api/admin/auth/reviews');
      if (mounted) setState(() { _reviews = data['reviews'] as List<dynamic>; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFeatured(String id, bool currentFeatured) async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      await client.put('/api/admin/auth/reviews/$id', body: { 'featured': !currentFeatured });
      _load();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteReview(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Delete Review?', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
        content: Text('Are you sure you want to delete this review?', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
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
    if (ok != true) return;
    if (!mounted) return;

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      await client.delete('/api/admin/auth/reviews/$id');
      _load();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Reviews', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppShimmer(width: 100, height: 16),
                          AppShimmer(width: 80, height: 12),
                        ],
                      ),
                      SizedBox(height: 8),
                      AppShimmer(width: 120, height: 14),
                      SizedBox(height: 12),
                      AppShimmer(width: double.infinity, height: 40, borderRadius: 8),
                    ],
                  ),
                ),
              ),
            )
          : _reviews.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(LucideIcons.starOff, size: 64, color: AppColors.textMuted.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text('No Reviews Yet', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text('When customers review products,\nthey will appear here.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.textMuted)),
                ]))
              : RefreshIndicator(
                  color: AppColors.primaryDark,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reviews.length,
                    itemBuilder: (context, index) {
                      final r = _reviews[index];
                      final rating = (r['rating'] as num?) ?? 0;
                      final bool featured = r['featured'] == true;
                      
                      final bool isUnread = !UnreadTracker.isRead('review', r['id']);
                      
                      return GestureDetector(
                        onTap: () {
                          if (isUnread) {
                            UnreadTracker.markAsRead('review', r['id']);
                            setState(() {});
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isUnread ? const Color(0xFFF59E0B).withValues(alpha: 0.3) : AppColors.cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.cardBorder.withValues(alpha: 0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                r['productName'] ?? 'Unknown Product',
                                                style: GoogleFonts.inter(fontSize: 15, fontWeight: isUnread ? FontWeight.bold : FontWeight.w600, color: AppColors.textPrimary),
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
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(LucideIcons.user, size: 12, color: AppColors.textMuted),
                                          const SizedBox(width: 4),
                                          Text(r['reviewerName'] ?? 'Anonymous', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(rating.toString(), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B))),
                                      const SizedBox(width: 4),
                                      Icon(LucideIcons.star, size: 14, color: const Color(0xFFF59E0B)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if ((r['comment'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  r['comment'],
                                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Divider(color: AppColors.divider, height: 1),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDate(r['createdAt']), style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _toggleFeatured(r['id'], featured),
                                      icon: Icon(featured ? LucideIcons.checkCircle2 : LucideIcons.circle, size: 14, color: featured ? AppColors.success : AppColors.textMuted),
                                      label: Text(featured ? 'Featured' : 'Feature', style: GoogleFonts.inter(fontSize: 12, color: featured ? AppColors.success : AppColors.textMuted, fontWeight: FontWeight.w600)),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    TextButton.icon(
                                      onPressed: () => _deleteReview(r['id']),
                                      icon: Icon(LucideIcons.trash2, size: 14, color: AppColors.error),
                                      label: Text('Delete', style: GoogleFonts.inter(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600)),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  ),
                ),
    );
  }

  String _formatDate(String? d) {
    if (d == null) return '';
    final dt = DateTime.tryParse(d);
    if (dt == null) return d;
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
