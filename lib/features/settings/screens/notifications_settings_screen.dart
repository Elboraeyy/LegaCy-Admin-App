import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/features/notifications/notification_provider.dart';

class NotificationsSettingsScreen extends StatelessWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Notification Settings',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.primaryDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Master Toggle ──
              _buildMasterToggle(context, provider),
              const SizedBox(height: 24),

              // ── Order Alerts ──
              _buildSectionTitle('Order Alerts', LucideIcons.trendingUp),
              _buildCategoryCard(
                context,
                provider: provider,
                category: 'order',
                title: 'New Orders',
                subtitle: 'Get alerted instantly when a customer places a new order',
                icon: LucideIcons.shoppingBag,
                color: const Color(0xFF3B82F6),
              ),
              const SizedBox(height: 12),

              // ── Inventory Alerts ──
              _buildSectionTitle('Inventory Alerts', LucideIcons.package),
              _buildCategoryCard(
                context,
                provider: provider,
                category: 'inventory',
                title: 'Stock Warnings',
                subtitle: 'Low stock and out-of-stock alerts for your products',
                icon: LucideIcons.alertTriangle,
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(height: 12),

              // ── Customer Engagement ──
              _buildSectionTitle('Customer Engagement', LucideIcons.heart),
              _buildCategoryCard(
                context,
                provider: provider,
                category: 'review',
                title: 'Product Reviews',
                subtitle: 'New customer reviews on your products',
                icon: LucideIcons.star,
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(height: 10),
              _buildCategoryCard(
                context,
                provider: provider,
                category: 'message',
                title: 'Contact Messages',
                subtitle: 'New messages from the contact form',
                icon: LucideIcons.mail,
                color: const Color(0xFF6366F1),
              ),
              const SizedBox(height: 10),
              _buildCategoryCard(
                context,
                provider: provider,
                category: 'restock',
                title: 'Restock Requests',
                subtitle: 'Customers waiting for out-of-stock items',
                icon: LucideIcons.bellRing,
                color: const Color(0xFF0EA5E9),
              ),
              const SizedBox(height: 12),

              // ── Financial ──
              _buildSectionTitle('Financial', LucideIcons.dollarSign),
              _buildCategoryCard(
                context,
                provider: provider,
                category: 'finance',
                title: 'Payment Alerts',
                subtitle: 'Payment received and financial summaries',
                icon: LucideIcons.dollarSign,
                color: const Color(0xFF10B981),
              ),
              const SizedBox(height: 12),

              // ── System ──
              _buildSectionTitle('System & Security', LucideIcons.shield),
              _buildCategoryCard(
                context,
                provider: provider,
                category: 'system',
                title: 'System Updates',
                subtitle: 'Staff login activity and system alerts',
                icon: LucideIcons.shield,
                color: const Color(0xFF0F766E),
              ),
              const SizedBox(height: 32),

              // ── Info Card ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryDark.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.info, size: 18, color: AppColors.primaryDark.withValues(alpha: 0.5)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Notifications are checked every 30 seconds while the app is running. Push notifications are delivered instantly for enabled categories.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMasterToggle(BuildContext context, NotificationProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryDark,
            AppColors.primaryDark.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              provider.globalEnabled ? LucideIcons.bell : LucideIcons.bellOff,
              size: 24,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Push Notifications',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  provider.globalEnabled
                      ? 'Notifications are active'
                      : 'All notifications are paused',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: provider.globalEnabled,
            onChanged: (v) {
              HapticFeedback.mediumImpact();
              provider.setGlobalEnabled(v);
            },
            activeTrackColor: AppColors.accent.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.accent),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required NotificationProvider provider,
    required String category,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final pushOn = provider.pushEnabled[category] ?? false;
    final soundOn = provider.soundEnabled[category] ?? false;
    final popupOn = provider.popupEnabled[category] ?? false;
    final isDisabled = !provider.globalEnabled;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isDisabled ? 0.5 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: pushOn && !isDisabled
                ? color.withValues(alpha: 0.2)
                : AppColors.cardBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: pushOn && !isDisabled
                  ? color.withValues(alpha: 0.06)
                  : AppColors.primaryDark.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),

            // Toggles
            _buildToggleRow(
              icon: LucideIcons.bell,
              label: 'Push Notification',
              description: 'Notification bar & lock screen',
              value: pushOn,
              color: color,
              onChanged: isDisabled
                  ? null
                  : (v) {
                      HapticFeedback.selectionClick();
                      provider.setPushEnabled(category, v);
                    },
            ),
            const SizedBox(height: 8),
            _buildToggleRow(
              icon: LucideIcons.volume2,
              label: 'Alert Sound',
              description: 'Play sound with notification',
              value: soundOn,
              color: color,
              onChanged: isDisabled || !pushOn
                  ? null
                  : (v) {
                      HapticFeedback.selectionClick();
                      provider.setSoundEnabled(category, v);
                    },
            ),
            const SizedBox(height: 8),
            _buildToggleRow(
              icon: LucideIcons.monitorSmartphone,
              label: 'Heads-Up Popup',
              description: 'Show floating popup on screen',
              value: popupOn,
              color: color,
              onChanged: isDisabled || !pushOn
                  ? null
                  : (v) {
                      HapticFeedback.selectionClick();
                      provider.setPopupEnabled(category, v);
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String label,
    required String description,
    required bool value,
    required Color color,
    required ValueChanged<bool>? onChanged,
  }) {
    final isDisabled = onChanged == null;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isDisabled ? 0.4 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isDisabled ? AppColors.textMuted : color.withValues(alpha: 0.6)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDisabled ? AppColors.textMuted : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: color.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}


