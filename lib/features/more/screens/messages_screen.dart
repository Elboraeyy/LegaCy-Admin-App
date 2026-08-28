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

class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({super.key});
  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  List<dynamic> _messages = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final data = await client.get('/api/admin/auth/messages');
      if (mounted) setState(() { _messages = data['messages'] as List<dynamic>; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      await client.put('/api/admin/auth/messages/$id', body: { 'status': status });
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteMessage(String id) async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      await client.delete('/api/admin/auth/messages/$id');
      if (mounted) Navigator.pop(context); // Close dialog
      _load();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(content: Text('Error: $e')));
    }
  }

  void _showMessageDetails(Map<String, dynamic> m) {
    if (m['status'] == 'NEW') {
      _updateStatus(m['id'], 'READ');
    }
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(LucideIcons.mail, color: const Color(0xFF6366F1)),
            const SizedBox(width: 12),
            Expanded(child: Text(m['subject'] ?? 'Message', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600, fontSize: 18))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('From: ${m['name'] ?? 'Unknown'}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text(m['email'] ?? '', style: GoogleFonts.inter(color: const Color(0xFF6366F1), fontSize: 13)),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Text(m['message'] ?? '', style: GoogleFonts.inter(color: AppColors.textSecondary, height: 1.5)),
              ),
              const SizedBox(height: 12),
              Text('Sent: ${_formatDate(m['createdAt'])}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            onPressed: () => _deleteMessage(m['id']),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(LucideIcons.trash2, size: 16),
            label: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Messages', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 5,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppShimmer(width: 48, height: 48, shape: BoxShape.circle),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            AppShimmer(width: 140, height: 15),
                            SizedBox(height: 4),
                            AppShimmer(width: 180, height: 12),
                            SizedBox(height: 12),
                            AppShimmer(width: 120, height: 14),
                            SizedBox(height: 6),
                            AppShimmer(width: double.infinity, height: 28, borderRadius: 8),
                            SizedBox(height: 12),
                            AppShimmer(width: 80, height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : _messages.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(LucideIcons.mailOpen, size: 64, color: const Color(0xFF6366F1)),
                  ),
                  const SizedBox(height: 16),
                  Text('Inbox Zero', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text('You have no new messages\nfrom the contact form.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.textMuted)),
                ]))
              : RefreshIndicator(
                  color: AppColors.primaryDark,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      final isUnread = m['status'] == 'NEW'; 
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isUnread ? AppColors.surface : AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isUnread ? const Color(0xFF6366F1).withValues(alpha: 0.3) : AppColors.cardBorder),
                          boxShadow: isUnread ? [
                            BoxShadow(
                              color: AppColors.cardBorder.withValues(alpha: 0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ] : [],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _showMessageDetails(m),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Avatar
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        (m['name'] ?? 'U')[0].toUpperCase(),
                                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF6366F1)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                m['name'] ?? 'Unknown Sender',
                                                style: GoogleFonts.inter(fontSize: 15, fontWeight: isUnread ? FontWeight.bold : FontWeight.w600, color: AppColors.textPrimary),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isUnread)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF6366F1),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                        if ((m['email'] ?? '').toString().isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            m['email'],
                                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6366F1)),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Text(
                                          m['subject'] ?? 'No Subject',
                                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          m['message'] ?? '',
                                          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Icon(LucideIcons.clock, size: 12, color: AppColors.textMuted),
                                            const SizedBox(width: 4),
                                            Text(_formatDate(m['createdAt']), style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
    
    final now = DateTime.now();
    final diff = now.difference(dt);
    
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    }
    
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
