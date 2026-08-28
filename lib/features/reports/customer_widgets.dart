import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:admin_app/core/theme/app_theme.dart';

String fmtNum(dynamic v) {
  if (v == null) return '0';
  final n = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toStringAsFixed(0);
}

Widget custKpi(String label, String value, IconData icon, Color color, {double? growth}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.cardBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: color)),
        if (growth != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: (growth >= 0 ? AppColors.success : AppColors.error).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text('${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(0)}%', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: growth >= 0 ? AppColors.success : AppColors.error)),
          ),
      ]),
      const SizedBox(height: 12),
      Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
    ]),
  );
}

Widget custSection(String title, IconData icon, Color color) {
  return Row(children: [
    Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 14, color: color)),
    const SizedBox(width: 10),
    Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
  ]);
}

// ── Segment Funnel ──
class SegmentFunnel extends StatelessWidget {
  final Map<String, dynamic> segments;
  const SegmentFunnel({super.key, required this.segments});

  @override
  Widget build(BuildContext context) {
    final items = [
      _Seg('Active', segments['active'] ?? 0, AppColors.success, LucideIcons.userCheck),
      _Seg('At Risk', segments['atRisk'] ?? 0, AppColors.warning, LucideIcons.alertTriangle),
      _Seg('Dormant', segments['dormant'] ?? 0, AppColors.textMuted, LucideIcons.userMinus),
      _Seg('Blocked', segments['blocked'] ?? 0, AppColors.error, LucideIcons.ban),
    ];
    final total = items.fold<int>(0, (s, i) => s + i.count);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        custSection('CUSTOMER SEGMENTS', LucideIcons.users, const Color(0xFF6366F1)),
        const SizedBox(height: 16),
        ...items.map((seg) {
          final pct = total > 0 ? seg.count / total : 0.0;
          return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
            Icon(seg.icon, size: 16, color: seg.color),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(seg.label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                Text('${seg.count}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: seg.color)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(value: pct, minHeight: 5, backgroundColor: AppColors.cardBorder, color: seg.color)),
            ])),
          ]));
        }),
      ]),
    );
  }
}

class _Seg { final String label; final int count; final Color color; final IconData icon; _Seg(this.label, this.count, this.color, this.icon); }

// ── Loyalty Card ──
class LoyaltyCard extends StatelessWidget {
  final Map<String, dynamic> loyalty;
  const LoyaltyCard({super.key, required this.loyalty});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        custSection('LOYALTY PROGRAM', LucideIcons.award, const Color(0xFFF59E0B)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            _loyaltyStat('Earned', fmtNum(loyalty['totalEarned']), AppColors.success),
            Container(width: 1, height: 36, color: AppColors.cardBorder),
            _loyaltyStat('Redeemed', fmtNum(loyalty['totalRedeemed']), AppColors.error),
            Container(width: 1, height: 36, color: AppColors.cardBorder),
            _loyaltyStat('Outstanding', fmtNum(loyalty['outstanding']), const Color(0xFFF59E0B)),
          ]),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${loyalty['members'] ?? 0} members', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
          Text('${loyalty['pointsPerEgp'] ?? 0} pts/EGP', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
        ]),
        if ((loyalty['topHolders'] as List?)?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Text('Top Holders', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
          const SizedBox(height: 6),
          ...(loyalty['topHolders'] as List).take(3).map((h) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(h['name'] ?? '', style: GoogleFonts.inter(fontSize: 11), overflow: TextOverflow.ellipsis),
              Text('${h['points']} pts', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFF59E0B))),
            ]),
          )),
        ],
      ]),
    );
  }

  Widget _loyaltyStat(String l, String v, Color c) => Expanded(child: Column(children: [
    Text(v, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: c)),
    const SizedBox(height: 2),
    Text(l, style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
  ]));
}

// ── Reviews Card ──
class ReviewsCard extends StatelessWidget {
  final Map<String, dynamic> reviews;
  const ReviewsCard({super.key, required this.reviews});

  @override
  Widget build(BuildContext context) {
    final dist = (reviews['distribution'] as List?) ?? [];
    final total = (reviews['total'] as num?)?.toInt() ?? 0;
    final avg = (reviews['avgRating'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        custSection('REVIEWS & RATINGS', LucideIcons.star, const Color(0xFFF59E0B)),
        const SizedBox(height: 16),
        Row(children: [
          Column(children: [
            Text(avg.toStringAsFixed(1), style: GoogleFonts.playfairDisplay(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
            Row(children: List.generate(5, (i) => Icon(i < avg.round() ? LucideIcons.star : LucideIcons.star, size: 14,
                color: i < avg.round() ? const Color(0xFFF59E0B) : AppColors.cardBorder))),
            const SizedBox(height: 4),
            Text('$total reviews', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
          ]),
          const SizedBox(width: 20),
          Expanded(child: Column(children: dist.map((d) {
            final stars = (d['stars'] as num?)?.toInt() ?? 0;
            final count = (d['count'] as num?)?.toInt() ?? 0;
            final pct = total > 0 ? count / total : 0.0;
            return Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
              Text('$stars', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Icon(LucideIcons.star, size: 10, color: const Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(value: pct, minHeight: 4, backgroundColor: AppColors.cardBorder, color: const Color(0xFFF59E0B)))),
              const SizedBox(width: 6),
              SizedBox(width: 24, child: Text('$count', style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted), textAlign: TextAlign.right)),
            ]));
          }).toList())),
        ]),
        // Recent reviews
        if ((reviews['recent'] as List?)?.isNotEmpty == true) ...[
          const SizedBox(height: 14),
          ...(reviews['recent'] as List).take(3).map((r) {
            final rating = (r['rating'] as num?)?.toInt() ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Row(children: List.generate(5, (i) => Icon(LucideIcons.star, size: 10, color: i < rating ? const Color(0xFFF59E0B) : AppColors.cardBorder))),
                  const SizedBox(width: 6),
                  Expanded(child: Text(r['name'] ?? '', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 4),
                Text(r['text'] ?? '', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(r['product'] ?? '', style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
              ]),
            );
          }),
        ],
      ]),
    );
  }
}

// ── Geographic Card ──
class GeoCard extends StatelessWidget {
  final List<dynamic> geography;
  const GeoCard({super.key, required this.geography});

  @override
  Widget build(BuildContext context) {
    if (geography.isEmpty) return const SizedBox.shrink();
    final maxOrders = geography.fold<int>(0, (m, g) => (g['orders'] as num).toInt() > m ? (g['orders'] as num).toInt() : m);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        custSection('GEOGRAPHIC DISTRIBUTION', LucideIcons.mapPin, const Color(0xFF7C3AED)),
        const SizedBox(height: 16),
        ...geography.take(8).map((g) {
          final orders = (g['orders'] as num?)?.toInt() ?? 0;
          final revenue = (g['revenue'] as num?)?.toDouble() ?? 0;
          final pct = maxOrders > 0 ? orders / maxOrders : 0.0;
          return Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(g['governorate'] ?? '', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
              Text('$orders orders · ${fmtNum(revenue)} EGP', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: pct, minHeight: 5, backgroundColor: AppColors.cardBorder, color: const Color(0xFF7C3AED))),
          ]));
        }),
      ]),
    );
  }
}

// ── Registration Trend ──
class RegTrendChart extends StatelessWidget {
  final List<dynamic> data;
  const RegTrendChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final maxY = data.fold<double>(0, (m, d) => (d['count'] as num).toDouble() > m ? (d['count'] as num).toDouble() : m);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        custSection('REGISTRATION TREND', LucideIcons.userPlus, const Color(0xFF0EA5E9)),
        const SizedBox(height: 20),
        SizedBox(height: 160, child: BarChart(BarChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: AppColors.cardBorder, strokeWidth: 0.5)),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  return Text((data[i]['month'] as String).substring(5), style: GoogleFonts.inter(fontSize: 8, color: AppColors.textMuted));
                })),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          maxY: maxY * 1.3 + 1,
          barGroups: data.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
            BarChartRodData(toY: (e.value['count'] as num).toDouble(), width: 18, color: const Color(0xFF0EA5E9).withValues(alpha: 0.8),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
          ])).toList(),
        ))),
      ]),
    );
  }
}
