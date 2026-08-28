import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/features/reports/stats_widgets.dart';

String fmtMoney(num v) {
  final n = v.toDouble();
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toStringAsFixed(0);
}

String fmtEgp(num v) => '${fmtMoney(v)} EGP';

/// Hero showing cash on hand + audited profit (source: Safe + Orders Audit)
class FinancialTruthHero extends StatelessWidget {
  final Map<String, dynamic> treasury;
  final Map<String, dynamic> audited;
  final Map<String, dynamic>? cashFlow;

  const FinancialTruthHero({
    super.key,
    required this.treasury,
    required this.audited,
    this.cashFlow,
  });

  @override
  Widget build(BuildContext context) {
    final totalCash = (treasury['totalBalance'] as num?)?.toDouble() ?? 0;
    final netProfit = (audited['netProfit'] as num?)?.toDouble() ?? 0;
    final revenue = (audited['revenue'] as num?)?.toDouble() ?? 0;
    final pending = (audited['pendingAuditInPeriod'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF12403C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.25),
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
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(LucideIcons.landmark, color: Color(0xFF12403C), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SOURCE OF TRUTH',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white54,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Treasury + Audited Orders',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (pending > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$pending audit pending',
                    style: GoogleFonts.inter(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            fmtEgp(totalCash),
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Text(
            'Total cash in all safes',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white12),
          const SizedBox(height: 14),
          Row(
            children: [
              _mini('Audited revenue', fmtEgp(revenue)),
              _vDiv(),
              _mini('Audited profit', fmtEgp(netProfit), highlight: netProfit >= 0),
              if (cashFlow != null) ...[
                _vDiv(),
                _mini('Period cash net', fmtEgp(cashFlow!['periodNet'] ?? 0)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _vDiv() => Container(width: 1, height: 32, color: Colors.white12);
  Widget _mini(String l, String v, {bool highlight = true}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(v, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: highlight ? Colors.white : AppColors.error)),
          Text(l, style: GoogleFonts.inter(fontSize: 9, color: Colors.white54)),
        ],
      ),
    );
  }
}

/// Cash in vs out bar chart (SafeTransaction)
class CashFlowBarChart extends StatelessWidget {
  final List<dynamic> dailyTrend;
  const CashFlowBarChart({super.key, required this.dailyTrend});

  @override
  Widget build(BuildContext context) {
    if (dailyTrend.isEmpty) return const SizedBox.shrink();
    final maxY = dailyTrend.fold<double>(0, (m, d) {
      final inn = (d['in'] as num?)?.toDouble() ?? 0;
      final out = (d['out'] as num?)?.toDouble() ?? 0;
      return max(m, max(inn, out));
    });

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'CASH FLOW (CASH SAFE)', icon: LucideIcons.arrowLeftRight, color: Color(0xFF0EA5E9)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY * 1.2 + 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: AppColors.cardBorder, strokeWidth: 0.5),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (v, _) => Text(fmtMoney(v), style: GoogleFonts.inter(fontSize: 8, color: AppColors.textMuted)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= dailyTrend.length) return const SizedBox.shrink();
                        final d = (dailyTrend[i]['date'] as String?)?.substring(5) ?? '';
                        return Text(d, style: GoogleFonts.inter(fontSize: 7, color: AppColors.textMuted));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: dailyTrend.asMap().entries.map((e) {
                  final inn = (e.value['in'] as num?)?.toDouble() ?? 0;
                  final out = (e.value['out'] as num?)?.toDouble() ?? 0;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(toY: inn, width: 6, color: AppColors.success.withValues(alpha: 0.85), borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
                      BarChartRodData(toY: out, width: 6, color: AppColors.error.withValues(alpha: 0.85), borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
                    ],
                    barsSpace: 4,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(AppColors.success, 'In'),
              const SizedBox(width: 16),
              _legend(AppColors.error, 'Out'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String l) => Row(
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Text(l, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
    ],
  );
}

/// Pie chart for expense types (operating / capital / amortized cash)
class ExpenseTypePieChart extends StatelessWidget {
  final Map<String, dynamic> byType;
  const ExpenseTypePieChart({super.key, required this.byType});

  @override
  Widget build(BuildContext context) {
    final op = (byType['operating'] as num?)?.toDouble() ?? 0;
    final cap = (byType['capital'] as num?)?.toDouble() ?? 0;
    final amort = (byType['amortized'] as num?)?.toDouble() ?? 0;
    final total = op + cap + amort;
    if (total <= 0) return const SizedBox.shrink();

    final sections = [
      if (op > 0) _section(op, AppColors.warning, 'Operating'),
      if (cap > 0) _section(cap, const Color(0xFFD4AF37), 'Capital'),
      if (amort > 0) _section(amort, AppColors.info, 'Amortized'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'EXPENSE CASH OUT', icon: LucideIcons.pieChart, color: AppColors.error),
          const SizedBox(height: 8),
          Text(
            'Full cash debited (Expenses screen)',
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 36,
                      sections: sections,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (op > 0) _pieLabel('Operating', op, total, AppColors.warning),
                      if (cap > 0) _pieLabel('Capital', cap, total, const Color(0xFFD4AF37)),
                      if (amort > 0) _pieLabel('Amortized', amort, total, AppColors.info),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PieChartSectionData _section(double v, Color c, String _) => PieChartSectionData(
    value: v,
    color: c,
    radius: 42,
    title: '',
  );

  Widget _pieLabel(String name, double v, double total, Color c) {
    final pct = total > 0 ? (v / total * 100).toStringAsFixed(0) : '0';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(name, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          Text('$pct%', style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

/// Cash movement by reference type table
class CashReferenceTable extends StatelessWidget {
  final List<dynamic> items;
  const CashReferenceTable({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'CASH BY SOURCE', icon: LucideIcons.table, color: Color(0xFF6366F1)),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1.2),
              3: FlexColumnWidth(0.6),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                children: _hdr(['Type', 'In', 'Out', '#']),
              ),
              ...items.map((row) {
                final type = row['type']?.toString() ?? '';
                final inn = (row['in'] as num?) ?? 0;
                final out = (row['out'] as num?) ?? 0;
                return TableRow(
                  children: [
                    _cell(type),
                    _cell(fmtEgp(inn), color: AppColors.success),
                    _cell(fmtEgp(out), color: AppColors.error),
                    _cell('${row['count'] ?? 0}'),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _hdr(List<String> t) => t.map((s) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    child: Text(s, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
  )).toList();

  Widget _cell(String t, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
    child: Text(t, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color ?? AppColors.textPrimary)),
  );
}

/// Delivered vs audited revenue (6 months) — Orders vs Orders Audit
class AuditedVsDeliveredChart extends StatelessWidget {
  final List<dynamic> monthlyComparison;
  const AuditedVsDeliveredChart({super.key, required this.monthlyComparison});

  @override
  Widget build(BuildContext context) {
    if (monthlyComparison.isEmpty) return const SizedBox.shrink();
    final maxY = monthlyComparison.fold<double>(0, (m, d) {
      final del = (d['delivered'] as num?)?.toDouble() ?? 0;
      final aud = (d['audited'] as num?)?.toDouble() ?? 0;
      return max(m, max(del, aud));
    });

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'DELIVERED VS AUDITED REVENUE',
            icon: LucideIcons.gitCompare,
            color: Color(0xFF6366F1),
          ),
          const SizedBox(height: 8),
          Text(
            'Delivered = pipeline · Audited = counted in treasury (Orders Audit)',
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxY * 1.15 + 50,
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= monthlyComparison.length) return const SizedBox.shrink();
                        final m = (monthlyComparison[i]['month'] as String?)?.substring(5) ?? '';
                        return Text(m, style: GoogleFonts.inter(fontSize: 8, color: AppColors.textMuted));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (v, _) => Text(fmtMoney(v), style: GoogleFonts.inter(fontSize: 8, color: AppColors.textMuted)),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: monthlyComparison.asMap().entries.map((e) {
                  final del = (e.value['delivered'] as num?)?.toDouble() ?? 0;
                  final aud = (e.value['audited'] as num?)?.toDouble() ?? 0;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(toY: del, width: 8, color: AppColors.info.withValues(alpha: 0.7), borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
                      BarChartRodData(toY: aud, width: 8, color: AppColors.success, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
                    ],
                    barsSpace: 4,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(AppColors.info, 'Delivered'),
              const SizedBox(width: 16),
              _legend(AppColors.success, 'Audited'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String l) => Row(
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Text(l, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
    ],
  );
}

/// Month closing net profit trend (Partners analytics)
class MonthClosingBarChart extends StatelessWidget {
  final List<dynamic> months;
  const MonthClosingBarChart({super.key, required this.months});

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) return const SizedBox.shrink();
    final spots = months.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (e.value['netProfit'] as num?)?.toDouble() ?? 0);
    }).toList();
    final maxAbs = spots.fold<double>(0, (m, s) => max(m, s.y.abs()));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'MONTH CLOSING NET PROFIT', icon: LucideIcons.calendarCheck, color: Color(0xFF8B5CF6)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxAbs * 1.2 + 50,
                minY: -maxAbs * 1.2 - 50,
                borderData: FlBorderData(show: false),
                barGroups: spots.map((s) => BarChartGroupData(
                  x: s.x.toInt(),
                  barRods: [
                    BarChartRodData(
                      toY: s.y,
                      width: 14,
                      color: s.y >= 0 ? AppColors.success : AppColors.error,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                )).toList(),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= months.length) return const SizedBox.shrink();
                        return Text(
                          months[i]['label']?.toString() ?? '',
                          style: GoogleFonts.inter(fontSize: 7, color: AppColors.textMuted),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Partner wallets summary hero
class PartnerWalletsHero extends StatelessWidget {
  final Map<String, dynamic> sot;
  const PartnerWalletsHero({super.key, required this.sot});

  @override
  Widget build(BuildContext context) {
    final wallet = (sot['totalWalletBalance'] as num?)?.toDouble() ?? 0;
    final pending = (sot['pendingWithdrawalCount'] as num?)?.toInt() ?? 0;
    final pendingAmt = (sot['pendingWithdrawalAmount'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4C1D95), Color(0xFF6D28D9)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PARTNER WALLETS (My Wallet)', style: GoogleFonts.inter(fontSize: 10, color: Colors.white54, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(fmtEgp(wallet), style: GoogleFonts.playfairDisplay(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 12),
          Row(
            children: [
              _chip('Pending withdrawals', '$pending · ${fmtEgp(pendingAmt)}'),
              const SizedBox(width: 8),
              _chip('Closed months', '${sot['monthClosingChart'] is List ? (sot['monthClosingChart'] as List).length : 0}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String l, String v) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(v, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(l, style: GoogleFonts.inter(fontSize: 9, color: Colors.white54)),
        ],
      ),
    ),
  );
}

/// KPI row for inventory / procurement
class OpsKpiRow extends StatelessWidget {
  final List<({String label, String value, IconData icon, Color color})> items;
  const OpsKpiRow({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: KpiCard(
              label: items[i].label,
              value: items[i].value,
              icon: items[i].icon,
              color: items[i].color,
            ),
          ),
        ],
      ],
    );
  }
}
