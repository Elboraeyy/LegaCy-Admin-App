import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:admin_app/core/theme/app_theme.dart';

// ── KPI Card ──
class KpiCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final double? growth;

  const KpiCard({super.key, required this.label, required this.value, required this.icon, required this.color, this.growth});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: color),
          ),
          if (growth != null) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (growth! >= 0 ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(growth! >= 0 ? LucideIcons.trendingUp : LucideIcons.trendingDown, size: 10, color: growth! >= 0 ? AppColors.success : AppColors.error),
                const SizedBox(width: 2),
                Text('${growth!.abs().toStringAsFixed(1)}%', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: growth! >= 0 ? AppColors.success : AppColors.error)),
              ]),
            ),
          ],
        ]),
        const SizedBox(height: 12),
        Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ── Section Header ──
class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const SectionHeader({super.key, required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 14, color: color),
      ),
      const SizedBox(width: 10),
      Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: 0.5)),
    ]);
  }
}

// ── Revenue Line Chart ──
class RevenueChart extends StatelessWidget {
  final List<dynamic> data;
  const RevenueChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final maxY = data.fold<double>(0, (m, d) => max(m, (d['revenue'] as num).toDouble()));
    final spots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['revenue'] as num).toDouble())).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader(title: 'REVENUE TREND (30 DAYS)', icon: LucideIcons.trendingUp, color: AppColors.success),
        const SizedBox(height: 20),
        SizedBox(
          height: 180,
          child: LineChart(LineChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: AppColors.cardBorder, strokeWidth: 0.5)),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40,
                getTitlesWidget: (v, _) => Text(_formatK(v), style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 7, reservedSize: 22,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  final d = (data[i]['date'] as String).substring(5);
                  return Text(d, style: GoogleFonts.inter(fontSize: 8, color: AppColors.textMuted));
                })),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            minY: 0, maxY: maxY * 1.15,
            lineBarsData: [
              LineChartBarData(
                spots: spots, isCurved: true, curveSmoothness: 0.3,
                color: AppColors.success, barWidth: 2.5,
                belowBarData: BarAreaData(show: true, color: AppColors.success.withValues(alpha: 0.08)),
                dotData: const FlDotData(show: false),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                  '${_formatK(s.y)} EGP\n${data[s.x.toInt()]['date']}',
                  GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                )).toList(),
              ),
            ),
          )),
        ),
      ]),
    );
  }

  String _formatK(double v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : v.toStringAsFixed(0);
}

// ── Orders Bar Chart ──
class OrdersBarChart extends StatelessWidget {
  final List<dynamic> data;
  const OrdersBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final last7 = data.length > 7 ? data.sublist(data.length - 7) : data;
    final maxY = last7.fold<double>(0, (m, d) => max(m, (d['orders'] as num).toDouble()));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader(title: 'ORDERS (LAST 7 DAYS)', icon: LucideIcons.shoppingBag, color: AppColors.info),
        const SizedBox(height: 20),
        SizedBox(
          height: 150,
          child: BarChart(BarChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: AppColors.cardBorder, strokeWidth: 0.5)),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= last7.length) return const SizedBox.shrink();
                  final d = (last7[i]['date'] as String).substring(8);
                  return Text(d, style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted));
                })),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            maxY: maxY * 1.3 + 1,
            barGroups: last7.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
              BarChartRodData(toY: (e.value['orders'] as num).toDouble(), width: 16,
                color: AppColors.info, borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
            ])).toList(),
          )),
        ),
      ]),
    );
  }
}

// ── Status Distribution ──
class StatusPieChart extends StatelessWidget {
  final Map<String, dynamic> data;
  const StatusPieChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.where((e) => (e.value as num) > 0).toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    final total = entries.fold<num>(0, (s, e) => s + (e.value as num));
    final colors = {'pending': AppColors.warning, 'processing': AppColors.info, 'shipped': const Color(0xFF7C3AED), 'delivered': AppColors.success, 'cancelled': AppColors.error};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader(title: 'ORDER STATUS', icon: LucideIcons.pieChart, color: const Color(0xFF7C3AED)),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: Row(children: [
            SizedBox(
              width: 140, height: 140,
              child: PieChart(PieChartData(
                sectionsSpace: 2, centerSpaceRadius: 30,
                sections: entries.map((e) => PieChartSectionData(
                  value: (e.value as num).toDouble(), title: '',
                  color: colors[e.key] ?? AppColors.textMuted, radius: 35,
                )).toList(),
              )),
            ),
            const SizedBox(width: 20),
            Expanded(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: entries.map((e) {
                final pct = ((e.value as num) / total * 100).toStringAsFixed(0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[e.key] ?? AppColors.textMuted, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.key.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                    Text('$pct%', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700)),
                  ]),
                );
              }).toList(),
            )),
          ]),
        ),
      ]),
    );
  }
}

// ── Ranked List Card ──
class RankedListCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<dynamic> items;
  final String Function(dynamic) getName;
  final String Function(dynamic) getValue;

  const RankedListCard({super.key, required this.title, required this.icon, required this.color, required this.items, required this.getName, required this.getValue});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader(title: title, icon: icon, color: color),
        const SizedBox(height: 14),
        ...items.take(7).toList().asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          final isTop3 = i < 3;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: isTop3 ? AppColors.accent.withValues(alpha: 0.15) : AppColors.cardBorder.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(child: Text('${i + 1}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isTop3 ? AppColors.accent : AppColors.textMuted))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(getName(item), style: GoogleFonts.inter(fontSize: 12, fontWeight: isTop3 ? FontWeight.w600 : FontWeight.w400), overflow: TextOverflow.ellipsis)),
              Text(getValue(item), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Breakdown Horizontal Bars ──
class BreakdownCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<dynamic> items;
  final String Function(dynamic) getLabel;
  final int Function(dynamic) getCount;

  const BreakdownCard({super.key, required this.title, required this.icon, required this.color, required this.items, required this.getLabel, required this.getCount});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final maxCount = items.fold<int>(0, (m, i) => max(m, getCount(i)));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader(title: title, icon: icon, color: color),
        const SizedBox(height: 14),
        ...items.map((item) {
          final c = getCount(item);
          final ratio = maxCount > 0 ? c / maxCount : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(getLabel(item), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
                Text('$c', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: ratio, minHeight: 6, backgroundColor: AppColors.cardBorder, color: color),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}
