import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'coupons_screen.dart';
import 'general_offers_screen.dart';
import 'shipping_promos_screen.dart';
import 'loyalty_promos_screen.dart';
import 'announcement_promos_screen.dart';
import 'sitewide_promos_screen.dart';
class PromotionsScreen extends StatelessWidget {
  const PromotionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Promos & Discounts', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.primaryDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Campaign Types',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          
          _buildPromoCard(
            context,
            title: 'Discount Coupons',
            subtitle: 'Create and manage reusable promo codes',
            icon: LucideIcons.ticket,
            color: const Color(0xFFF59E0B),
            screen: const CouponsScreen(),
          ),
          const SizedBox(height: 12),
          
          _buildPromoCard(
            context,
            title: 'Product Offers',
            subtitle: 'Standard percentage or fixed discounts on products',
            icon: LucideIcons.tag,
            color: const Color(0xFF10B981),
            screen: const GeneralOffersScreen(),
          ),
          const SizedBox(height: 12),

          _buildPromoCard(
            context,
            title: 'Shipping Options',
            subtitle: 'Manage free shipping thresholds & rates',
            icon: LucideIcons.truck,
            color: const Color(0xFF0EA5E9),
            screen: const ShippingPromosScreen(),
          ),
          const SizedBox(height: 12),

          _buildPromoCard(
            context,
            title: 'Loyalty Program',
            subtitle: 'Manage reward points and customer tiers',
            icon: LucideIcons.star,
            color: const Color(0xFFEAB308),
            screen: const LoyaltyPromosScreen(),
          ),
          const SizedBox(height: 12),

          _buildPromoCard(
            context,
            title: 'Announcement Bar',
            subtitle: 'Global store notifications and top bar alerts',
            icon: LucideIcons.megaphone,
            color: const Color(0xFFEC4899),
            screen: const AnnouncementPromosScreen(),
          ),
          const SizedBox(height: 12),

          _buildPromoCard(
            context,
            title: 'Site-Wide Offer',
            subtitle: 'Global discounts applied across the entire store',
            icon: LucideIcons.target,
            color: const Color(0xFF14B8A6),
            screen: const SitewidePromosScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required Widget screen}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 20, color: AppColors.textMuted.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
