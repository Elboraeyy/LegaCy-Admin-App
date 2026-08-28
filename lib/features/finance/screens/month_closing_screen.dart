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
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:arabic_reshaper/arabic_reshaper.dart';
import 'package:gal/gal.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

class MonthClosingScreen extends StatefulWidget {
  const MonthClosingScreen({super.key});

  @override
  State<MonthClosingScreen> createState() => _MonthClosingScreenState();
}

class _MonthClosingScreenState extends State<MonthClosingScreen> {
  bool _loading = true;
  Map<String, dynamic> _closing = {};
  int _pendingAuditCount = 0;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  bool _closingInProgress = false;
  final _currencyFormat = NumberFormat('#,##0.00', 'en');
  List<dynamic> _safes = [];
  String? _selectedBrandSafeId;
  int _currentStage = 0; // 0: Sales/Revenue, 1: Expenses/Deductions, 2: Distributions/Shares, 3: Report Preview

  @override
  void initState() {
    super.initState();
    _loadClosing();
  }

  Future<void> _loadClosing() async {
    setState(() => _loading = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final res = await client.get('/api/admin/auth/finance/month-closing?month=$_month&year=$_year');
      if (mounted) {
        setState(() {
          _closing = Map<String, dynamic>.from(res['closing'] ?? {});
          if (_closing['partnerDistributions'] != null) {
            final List<dynamic> list = List<dynamic>.from(_closing['partnerDistributions']);
            list.sort((a, b) {
              final double shareA = (a['sharePercentage'] ?? 0).toDouble();
              final double shareB = (b['sharePercentage'] ?? 0).toDouble();
              return shareB.compareTo(shareA);
            });
            _closing['partnerDistributions'] = list;
          }
          _pendingAuditCount = res['pendingAuditCount'] ?? 0;
          _safes = List<dynamic>.from(res['safes'] ?? []);
          
          if (_safes.isNotEmpty) {
            final officeSafe = _safes.firstWhere(
              (s) => s['name'] == 'Cash',
              orElse: () => _safes.first,
            );
            _selectedBrandSafeId = officeSafe['id']?.toString();
          } else {
            _selectedBrandSafeId = null;
          }
          
          final status = _closing['status'] ?? 'DRAFT';
          final isClosed = status == 'CLOSED' || status == 'LOCKED';
          if (isClosed) {
            _currentStage = 3;
          } else {
            _currentStage = 0;
          }
          
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _closeMonth() async {
    if (_closingInProgress) return;
    setState(() => _closingInProgress = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      await client.post('/api/admin/auth/finance/month-closing', body: {
        'month': _month,
        'year': _year,
        'brandSafeId': _selectedBrandSafeId,
        ..._closing,
      });
      await _loadClosing();
      if (mounted) {
        ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(
          content: Text('Month ${DateFormat('MMMM yyyy').format(DateTime(_year, _month))} closed successfully! ✓'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _closingInProgress = false);
    }
  }

  void _confirmCloseMonth() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(LucideIcons.alertTriangle, color: AppColors.warning),
            const SizedBox(width: 12),
            Text(
              'Confirm Close Month',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'This will distribute profits to partners, deposit the Brand reinvestment share into the selected safe, and lock all financial records for this month. This action cannot be easily undone.\n\nAre you sure you want to proceed?',
          style: GoogleFonts.inter(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _closeMonth();
            },
            child: const Text('Close Month Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPendingAuditWarning() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(LucideIcons.alertTriangle, color: AppColors.warning),
            const SizedBox(width: 12),
            Text(
              'Un-audited Orders Warning',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'There are $_pendingAuditCount delivered orders for this month that have not been financially audited yet.\n\nIf you proceed, the costs and revenues of these orders will be excluded from this month\'s closing calculations.\n\nDo you want to continue?',
          style: GoogleFonts.inter(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Go to Audit', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _currentStage++;
              });
            },
            child: const Text('Continue Anyway', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(dynamic value) {
    final double val = (value ?? 0).toDouble();
    return _currencyFormat.format(val);
  }

  bool _hasArabic(String text) {
    return RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(text);
  }

  String _reshapeText(String text) {
    if (_hasArabic(text)) {
      return ArabicReshaper.instance.reshape(text);
    }
    return text;
  }

  Future<pw.Document> _generateInvoicePdf() async {
    final pdfDoc = pw.Document();
    final fontRegular = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    const primaryColor = PdfColor.fromInt(0xFF12403C);
    const accentColor = PdfColor.fromInt(0xFFD4AF37);
    const textDark = PdfColor.fromInt(0xFF2C3E50);
    const greyColor = PdfColor.fromInt(0xFF7F8C8D);
    const lightBg = PdfColor.fromInt(0xFFFCF8F3);

    pw.Widget pdfText(String text, {double size = 9, bool isBold = false, PdfColor? color, pw.TextAlign align = pw.TextAlign.left}) {
      final isAr = _hasArabic(text);
      return pw.Text(
        _reshapeText(text),
        textAlign: align,
        textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        style: pw.TextStyle(
          font: isBold ? fontBold : fontRegular,
          fontSize: size,
          color: color ?? textDark,
        ),
      );
    }

    final String monthName = DateFormat('MMMM yyyy').format(DateTime(_year, _month));
    final String statusStr = (_closing['status'] ?? 'DRAFT') == 'CLOSED' ? 'CLOSED' : 'DRAFT / PREVIEW';

    pdfDoc.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: PdfColors.white),
          ),
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header Banner
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: const pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pdfText('LegaCy Store', size: 18, isBold: true, color: PdfColors.white),
                        pw.SizedBox(height: 4),
                        pdfText('Monthly Financial Closing Report', size: 12, isBold: true, color: accentColor),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pdfText(monthName, size: 12, isBold: true, color: PdfColors.white),
                        pw.SizedBox(height: 4),
                        pdfText('Status: $statusStr', size: 10, color: PdfColors.white),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Summary Sections Grid (Two columns)
              pw.Table(
                columnWidths: const {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    children: [
                      // Column 1: Sales & Revenue Breakdown
                      pw.Container(
                        height: 245,
                        margin: const pw.EdgeInsets.only(right: 8),
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.only(bottom: 6),
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(bottom: pw.BorderSide(color: primaryColor, width: 1.5)),
                              ),
                              child: pdfText('Sales & Gross Profit Summary', size: 11, isBold: true, color: primaryColor),
                            ),
                            pw.SizedBox(height: 6),
                            _buildPdfRow(pdfText, 'Sales Revenue', 'EGP ${_formatCurrency(_closing['totalRevenue'])}'),
                            _buildPdfRow(pdfText, 'Discounts (Info)', 'EGP ${_formatCurrency(_closing['totalDiscounts'])}', color: greyColor),
                            _buildPdfRow(pdfText, 'COGS', '- EGP ${_formatCurrency(_closing['totalCOGS'])}', isNegative: true),
                            _buildPdfRow(pdfText, 'Shipping Costs', '- EGP ${_formatCurrency(_closing['totalShippingCosts'])}', isNegative: true),
                            _buildPdfRow(pdfText, 'Packaging Costs', '- EGP ${_formatCurrency(_closing['totalPackagingCosts'])}', isNegative: true),
                            _buildPdfRow(pdfText, 'Extra Expenses', '- EGP ${_formatCurrency(_closing['totalExtraExpenses'])}', isNegative: true),
                            pw.Spacer(),
                            pw.Divider(color: PdfColors.grey300),
                            _buildPdfRow(pdfText, 'Gross Profit', 'EGP ${_formatCurrency(_closing['grossProfit'])}', isBold: true, color: primaryColor),
                          ],
                        ),
                      ),

                      // Column 2: Operating Expenses & Net Profit
                      pw.Container(
                        height: 245,
                        margin: const pw.EdgeInsets.only(left: 8),
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.only(bottom: 6),
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(bottom: pw.BorderSide(color: primaryColor, width: 1.5)),
                              ),
                              child: pdfText('Expenses & Net Profit Summary', size: 11, isBold: true, color: primaryColor),
                            ),
                            pw.SizedBox(height: 6),
                            _buildPdfRow(pdfText, 'Gross Profit', 'EGP ${_formatCurrency(_closing['grossProfit'])}'),
                            _buildPdfRow(pdfText, 'Operating Exp.', '- EGP ${_formatCurrency(_closing['totalOperatingExpenses'])}', isNegative: true),
                            _buildPdfRow(pdfText, 'Amortized Exp.', '- EGP ${_formatCurrency(_closing['totalAmortizedExpenses'])}', isNegative: true),
                            if ((_closing['manualAdjustment'] ?? 0) != 0)
                              _buildPdfRow(pdfText, 'Man. Adjustment', 'EGP ${_formatCurrency(_closing['manualAdjustment'])}'),
                            pw.Spacer(),
                            pw.Divider(color: PdfColors.grey300),
                            _buildPdfRow(
                              pdfText,
                              'Net Profit',
                              'EGP ${_formatCurrency(_closing['netProfit'])}',
                              isBold: true,
                              isNegative: ((_closing['netProfit'] ?? 0).toDouble() < 0),
                              color: ((_closing['netProfit'] ?? 0).toDouble() >= 0) ? PdfColors.green800 : null,
                            ),
                            pw.SizedBox(height: 6),
                            // Distribution Summary
                            pw.Container(
                              padding: const pw.EdgeInsets.all(6),
                              color: lightBg,
                              child: pw.Column(
                                children: [
                                  _buildPdfRow(
                                    pdfText,
                                    'Brand (40%)',
                                    'EGP ${_formatCurrency(_closing['reinvestmentAmount'])}',
                                    isNegative: ((_closing['reinvestmentAmount'] ?? 0).toDouble() < 0),
                                    color: ((_closing['reinvestmentAmount'] ?? 0).toDouble() >= 0) ? primaryColor : null,
                                  ),
                                  _buildPdfRow(
                                    pdfText,
                                    'Partners (60%)',
                                    'EGP ${_formatCurrency(_closing['distributionAmount'])}',
                                    isNegative: ((_closing['distributionAmount'] ?? 0).toDouble() < 0),
                                    color: ((_closing['distributionAmount'] ?? 0).toDouble() >= 0) ? accentColor : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Brand Reinvestment Details
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pdfText('Cumulative Brand Capital:', isBold: true, color: primaryColor),
                    pdfText('EGP ${_formatCurrency(_closing['cumulativeReinvestment'])}', isBold: true, size: 12, color: primaryColor),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Partner Distribution Table Title
              pdfText('Partner Monthly & Cumulative Splits', size: 12, isBold: true, color: primaryColor),
              pw.SizedBox(height: 8),

              // Table header
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2.0), // Name
                  1: pw.FlexColumnWidth(1.4), // Share Worth
                  2: pw.FlexColumnWidth(1.2), // Profit
                  3: pw.FlexColumnWidth(1.2), // Salary
                  4: pw.FlexColumnWidth(1.4), // Month Total
                  5: pw.FlexColumnWidth(1.6), // Cum. Profit
                  6: pw.FlexColumnWidth(1.6), // Cum. Salary
                  7: pw.FlexColumnWidth(1.8), // Cum. Total
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: primaryColor),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pdfText('Partner', color: PdfColors.white, isBold: true, align: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pdfText('Share Worth', color: PdfColors.white, isBold: true, align: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pdfText('Profit', color: PdfColors.white, isBold: true, align: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pdfText('Salary', color: PdfColors.white, isBold: true, align: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pdfText('Month Total', color: PdfColors.white, isBold: true, align: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pdfText('Cum. Profit', color: PdfColors.white, isBold: true, align: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pdfText('Cum. Salary', color: PdfColors.white, isBold: true, align: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pdfText('Cum. Total', color: PdfColors.white, isBold: true, align: pw.TextAlign.center)),
                    ],
                  ),
                  ...(() {
                    final list = List<dynamic>.from(_closing['partnerDistributions'] ?? []);
                    list.sort((a, b) {
                      final double shareA = (a['sharePercentage'] ?? 0).toDouble();
                      final double shareB = (b['sharePercentage'] ?? 0).toDouble();
                      return shareB.compareTo(shareA);
                    });
                    return list;
                  }()).map((p) {
                    final pd = Map<String, dynamic>.from(p);
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pdfText(pd['partnerName'] ?? '', align: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pdfText(_formatCurrency(pd['currentCapitalWorth']), align: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pdfText(_formatCurrency(pd['profitShare']), align: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pdfText(_formatCurrency(pd['salaryShare']), align: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pdfText(_formatCurrency(pd['totalShare']), isBold: true, align: pw.TextAlign.center, color: primaryColor)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pdfText(_formatCurrency(pd['cumulativeProfitShare']), align: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pdfText(_formatCurrency(pd['cumulativeSalaryShare']), align: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pdfText(_formatCurrency(pd['cumulativeTotalShare']), isBold: true, align: pw.TextAlign.center, color: PdfColors.green800)),
                      ],
                    );
                  }),
                ],
              ),
              pw.Spacer(),

              // Signatures
              pw.Divider(color: PdfColors.grey400, thickness: 1),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pdfText('CFO Signature: ____________________', color: greyColor),
                  pdfText('Printed At: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}', color: greyColor),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdfDoc;
  }

  pw.Widget _buildPdfRow(pw.Widget Function(String, {double size, bool isBold, PdfColor? color, pw.TextAlign align}) pdfText, String label, String value, {bool isNegative = false, bool isBold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pdfText(label, isBold: isBold, color: color),
          pdfText(value, isBold: isBold || isNegative, color: isNegative ? PdfColors.red800 : (color ?? PdfColors.black)),
        ],
      ),
    );
  }

  Future<void> _processInvoice({required String action}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pdfDoc = await _generateInvoicePdf();
      final bytes = await pdfDoc.save();
      final docName = 'MonthClosing_${_year}_$_month';

      if (action == 'save_image' || action == 'share_image') {
        final raster = await Printing.raster(bytes, pages: [0], dpi: 300).first;
        final rawPngBytes = await raster.toPng();
        final pngBytes = await _fillImageBackgroundWithWhite(rawPngBytes);
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$docName.png');
        await file.writeAsBytes(pngBytes);

        if (action == 'save_image') {
          bool hasAccess = await Gal.hasAccess(toAlbum: true);
          if (!hasAccess) {
            hasAccess = await Gal.requestAccess(toAlbum: true);
          }
          if (hasAccess) {
            await Gal.putImage(file.path, album: 'LegaCy');
            messenger.showAppToast(
              AppToast.snackBar(
                content: const Text('Saved report image to photo library successfully!'),
                backgroundColor: AppColors.success,
              ),
            );
          } else {
            messenger.showAppToast(
              AppToast.snackBar(
                content: const Text('Storage permission denied.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        } else {
          await Share.shareXFiles([
            XFile(file.path),
          ], text: 'Monthly Finance Closing Report for $_month / $_year');
        }
      } else {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
          name: docName,
        );
      }
    } catch (e) {
      messenger.showAppToast(
        AppToast.snackBar(
          content: Text('Error generating report: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _closing['status'] ?? 'DRAFT';
    final isClosed = status == 'CLOSED' || status == 'LOCKED';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Month Closing',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.chevronLeft, size: 20),
            onPressed: _closingInProgress
                ? null
                : () {
                    setState(() {
                      if (_month == 1) {
                        _month = 12;
                        _year--;
                      } else {
                        _month--;
                      }
                    });
                    _loadClosing();
                  },
          ),
          Text(
            DateFormat('yyyy - MM').format(DateTime(_year, _month)),
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryDark),
          ),
          IconButton(
            icon: const Icon(LucideIcons.chevronRight, size: 20),
            onPressed: _closingInProgress
                ? null
                : () {
                    setState(() {
                      if (_month == 12) {
                        _month = 1;
                        _year++;
                      } else {
                        _month++;
                      }
                    });
                    _loadClosing();
                  },
          ),
        ],
      ),
      body: _loading
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const AppShimmer(width: double.infinity, height: 40, borderRadius: 12),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        AppShimmer(width: 150, height: 16),
                        SizedBox(height: 20),
                        AppShimmer(width: double.infinity, height: 100, borderRadius: 16),
                        SizedBox(height: 20),
                        AppShimmer(width: 120, height: 14),
                        SizedBox(height: 8),
                        AppShimmer(width: double.infinity, height: 48, borderRadius: 12),
                        SizedBox(height: 24),
                        AppShimmer(width: double.infinity, height: 48, borderRadius: 12),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                if (!isClosed) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildStageIndicator(),
                  ),
                ],
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadClosing,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      child: _buildStageContent(isClosed),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomBar(isClosed),
    );
  }

  Widget _buildStageIndicator() {
    final stages = ['Revenue', 'Expenses', 'Splits', 'Report'];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: List.generate(stages.length, (index) {
          final isCurrent = _currentStage == index;
          final isDone = _currentStage > index;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppColors.primaryDark
                              : (isDone ? AppColors.success : Colors.grey.shade200),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : Text(
                                  '${index + 1}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrent ? Colors.white : Colors.grey.shade600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        stages[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent ? AppColors.primaryDark : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < stages.length - 1)
                  Container(
                    width: 14,
                    height: 2,
                    color: isDone ? AppColors.success : Colors.grey.shade200,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStageContent(bool isClosed) {
    if (isClosed) {
      return _buildStage4ReportPreview(isClosed);
    }
    switch (_currentStage) {
      case 0:
        return _buildStage1Sales();
      case 1:
        return _buildStage2Expenses();
      case 2:
        return _buildStage3Distribution();
      case 3:
        return _buildStage4ReportPreview(isClosed);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStage1Sales() {
    final revenue = (_closing['totalRevenue'] ?? 0).toDouble();
    final cogs = (_closing['totalCOGS'] ?? 0).toDouble();
    final shipping = (_closing['totalShippingCosts'] ?? 0).toDouble();
    final packaging = (_closing['totalPackagingCosts'] ?? 0).toDouble();
    final extra = (_closing['totalExtraExpenses'] ?? 0).toDouble();
    final discounts = (_closing['totalDiscounts'] ?? 0).toDouble();
    final grossProfit = (_closing['grossProfit'] ?? 0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_pendingAuditCount > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.alertTriangle, color: AppColors.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Warning: $_pendingAuditCount delivered orders are pending financial audit review.',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.warning, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

        // Stats grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            _buildStatCard('Total Orders', '${_closing['totalOrders'] ?? 0}', LucideIcons.shoppingBag, AppColors.primaryDark),
            _buildStatCard('Audited Orders', '${_closing['auditedOrders'] ?? 0}', LucideIcons.checkCircle, AppColors.success),
            _buildStatCard('Cancelled Orders', '${_closing['cancelledOrders'] ?? 0}', LucideIcons.xCircle, AppColors.error),
            _buildStatCard('Pending Audit', '$_pendingAuditCount', LucideIcons.clock, AppColors.warning),
          ],
        ),
        const SizedBox(height: 20),

        // Cost structure breakdown
        _sectionTitle('Gross Profit Calculation (Audited Orders)', LucideIcons.barChart3, AppColors.primaryDark),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              _buildFinanceRow('Sales Revenue', revenue, isPrimary: true),
              const Divider(height: 20),
              _buildFinanceRow('COGS (Wholesale Costs)', -cogs, isNegative: true),
              _buildFinanceRow('Actual Shipping Costs', -shipping, isNegative: true),
              _buildFinanceRow('Packaging Costs', -packaging, isNegative: true),
              _buildFinanceRow('Extra Order Expenses', -extra, isNegative: true),
              _buildFinanceRow('Discounts Given', -discounts, isNegative: true),
              const Divider(height: 20),
              _buildFinanceRow(
                'Gross Profit',
                grossProfit,
                isBold: true,
                color: AppColors.success,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStage2Expenses() {
    final grossProfit = (_closing['grossProfit'] ?? 0).toDouble();
    final operating = (_closing['totalOperatingExpenses'] ?? 0).toDouble();
    final amortized = (_closing['totalAmortizedExpenses'] ?? 0).toDouble();
    final netProfit = (_closing['netProfit'] ?? 0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Operating & Monthly Amortized Expenses', LucideIcons.wallet, AppColors.warning),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              _buildFinanceRow('Gross Profit', grossProfit, isPrimary: true),
              const Divider(height: 20),
              _buildFinanceRow('Direct Operating Expenses', -operating, isNegative: true),
              _buildFinanceRow('Amortized Expenses Portion', -amortized, isNegative: true),
              const Divider(height: 20),
              _buildFinanceRow(
                'Net Profit for ${DateFormat('MMMM').format(DateTime(_year, _month))}',
                netProfit,
                isBold: true,
                color: netProfit >= 0 ? AppColors.success : AppColors.error,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Net Profit gradient display
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: netProfit >= 0
                  ? [AppColors.success, const Color(0xFF047857)]
                  : [AppColors.error, const Color(0xFF991B1B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (netProfit >= 0 ? AppColors.success : AppColors.error).withOpacity(0.3),
                offset: const Offset(0, 8),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Project Net Profit for This Month',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'EGP ${_formatCurrency(netProfit)}',
                style: GoogleFonts.inter(fontSize: 28, color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStage3Distribution() {
    final netProfit = (_closing['netProfit'] ?? 0).toDouble();
    final reinvestment = (_closing['reinvestmentAmount'] ?? 0).toDouble();
    final distribution = (_closing['distributionAmount'] ?? 0).toDouble();
    final profitShare = (_closing['profitShareAmount'] ?? 0).toDouble();
    final salaryShare = (_closing['salaryShareAmount'] ?? 0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Brand Reinvestment Treasury', LucideIcons.wallet2, AppColors.info),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select the safe to receive the 40% Brand reinvestment amount:',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              if (_safes.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedBrandSafeId,
                  isExpanded: true,
                  icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textMuted),
                  dropdownColor: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _safes.map((s) {
                    return DropdownMenuItem<String>(
                      value: s['id']?.toString(),
                      child: Text(
                        '${s['name']} (EGP ${_formatCurrency(s['balance'])})',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedBrandSafeId = val);
                  },
                )
              else
                const Text('Loading safes...'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _sectionTitle('Distribution Splits & Splits Preview', LucideIcons.pieChart, AppColors.accent),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              _buildFinanceRow('Project Net Profit', netProfit, isPrimary: true, color: netProfit >= 0 ? AppColors.success : AppColors.error),
              const Divider(height: 20),
              _buildFinanceRow('Brand Reinvestment (40%)', reinvestment, color: reinvestment >= 0 ? AppColors.info : AppColors.error),
              _buildFinanceRow('Partner Distributions (60%)', distribution, color: distribution >= 0 ? AppColors.accent : AppColors.error),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    _buildFinanceRow('- Capital Return (70% of 60%)', profitShare, isSecondarySub: true),
                    _buildFinanceRow('- Salaries Share (30% of 60%)', salaryShare, isSecondarySub: true),
                  ],
                ),
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('Cumulative Brand Capital:', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                  ),
                  const SizedBox(width: 8),
                  Text('EGP ${_formatCurrency(_closing['cumulativeReinvestment'])}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _sectionTitle('Partner Distributions Breakdown', LucideIcons.users, AppColors.success),
        ...(_closing['partnerDistributions'] as List? ?? []).map((p) {
          final pd = Map<String, dynamic>.from(p);
          final double sharePercent = (pd['sharePercentage'] ?? 0).toDouble();
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 24,
                          decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          pd['partnerName'] ?? '',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Share: ${(sharePercent * 100).toStringAsFixed(0)}%',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Worth: EGP ${_formatCurrency(pd['currentCapitalWorth'])}',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),
                // Monthly distributed
                Row(
                  children: [
                    Expanded(
                      child: _buildShareItemDetail('Capital Return (Month)', pd['profitShare']),
                    ),
                    Expanded(
                      child: _buildShareItemDetail('Salary (Month)', pd['salaryShare']),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Earned (Current Month):', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                    Text('EGP ${_formatCurrency(pd['totalShare'])}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                  ],
                ),
                const Divider(height: 20),
                // Cumulative totals
                Row(
                  children: [
                    Expanded(
                      child: _buildShareItemDetail('Capital Return (Cumulative)', pd['cumulativeProfitShare'], isCumulative: true),
                    ),
                    Expanded(
                      child: _buildShareItemDetail('Salary (Cumulative)', pd['cumulativeSalaryShare'], isCumulative: true),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Earned Since Inception:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
                    Text('EGP ${_formatCurrency(pd['cumulativeTotalShare'])}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.success)),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<Uint8List> _fillImageBackgroundWithWhite(Uint8List pngBytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(pngBytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image image = frameInfo.image;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    final ui.Paint paint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);

    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      paint,
    );

    canvas.drawImage(image, ui.Offset.zero, ui.Paint());

    final ui.Picture picture = recorder.endRecording();
    final ui.Image whiteBgImage = await picture.toImage(image.width, image.height);
    final ByteData? byteData = await whiteBgImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Widget _buildShareItemDetail(String label, dynamic value, {bool isCumulative = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'EGP ${_formatCurrency(value)}',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isCumulative ? AppColors.textSecondary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildStage4ReportPreview(bool isClosed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Financial Closing Report Preview', LucideIcons.fileText, AppColors.primaryDark),
        
        // Report Mockup Container
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                offset: const Offset(0, 10),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mockup Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LegaCy Store', style: GoogleFonts.playfairDisplay(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Monthly Financial Closing Report', style: GoogleFonts.inter(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          DateFormat('MMMM yyyy').format(DateTime(_year, _month)),
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        Text(
                          isClosed ? 'Status: CLOSED' : 'Status: DRAFT',
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Overview grid
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInvoiceDetailRow('Sales Revenue', _closing['totalRevenue']),
                        _buildInvoiceDetailRow('Discounts (Info)', _closing['totalDiscounts'] ?? 0, color: AppColors.textMuted),
                        _buildInvoiceDetailRow('COGS', -(_closing['totalCOGS'] ?? 0), isNegative: true),
                        _buildInvoiceDetailRow('Shipping Costs', -(_closing['totalShippingCosts'] ?? 0), isNegative: true),
                        _buildInvoiceDetailRow('Packaging Costs', -(_closing['totalPackagingCosts'] ?? 0), isNegative: true),
                        _buildInvoiceDetailRow('Extra Expenses', -(_closing['totalExtraExpenses'] ?? 0), isNegative: true),
                        const Divider(height: 12),
                        _buildInvoiceDetailRow('Gross Profit', _closing['grossProfit'], isBold: true),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInvoiceDetailRow('Gross Profit', _closing['grossProfit']),
                        _buildInvoiceDetailRow('Operating Exp.', -(_closing['totalOperatingExpenses'] ?? 0), isNegative: true),
                        _buildInvoiceDetailRow('Amortized Exp.', -(_closing['totalAmortizedExpenses'] ?? 0), isNegative: true),
                        const Divider(height: 12),
                        _buildInvoiceDetailRow(
                          'Net Profit',
                          _closing['netProfit'],
                          isBold: true,
                          color: ((_closing['netProfit'] ?? 0).toDouble() >= 0) ? AppColors.success : AppColors.error,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(6)),
                          child: Column(
                            children: [
                              _buildInvoiceDetailRow(
                                'Brand (40%)',
                                _closing['reinvestmentAmount'],
                                size: 10,
                                color: ((_closing['reinvestmentAmount'] ?? 0).toDouble() >= 0) ? AppColors.primaryDark : AppColors.error,
                              ),
                              _buildInvoiceDetailRow(
                                'Partners (60%)',
                                _closing['distributionAmount'],
                                size: 10,
                                color: ((_closing['distributionAmount'] ?? 0).toDouble() >= 0) ? AppColors.primaryDark : AppColors.error,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Cumulative brand capital
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                color: AppColors.primaryLight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Cumulative Brand Capital:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                    Text('EGP ${_formatCurrency(_closing['cumulativeReinvestment'])}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                  ],
                ),
              ),
              const Divider(height: 24),

              // Partner shares table
              Text('Partner Monthly & Cumulative Splits:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
              const SizedBox(height: 6),
              Table(
                border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
                columnWidths: const {
                  0: FlexColumnWidth(1.6), // Partner
                  1: FlexColumnWidth(1.8), // Share Worth
                  2: FlexColumnWidth(1.4), // Profit
                  3: FlexColumnWidth(1.4), // Salary
                  4: FlexColumnWidth(1.8), // Cum. Total
                },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: AppColors.primaryDark),
                    children: [
                      _buildTableHeaderCell('Partner'),
                      _buildTableHeaderCell('Share Worth'),
                      _buildTableHeaderCell('Profit'),
                      _buildTableHeaderCell('Salary'),
                      _buildTableHeaderCell('Cum. Total'),
                    ],
                  ),
                  ...(() {
                    final list = List<dynamic>.from(_closing['partnerDistributions'] ?? []);
                    list.sort((a, b) {
                      final double shareA = (a['sharePercentage'] ?? 0).toDouble();
                      final double shareB = (b['sharePercentage'] ?? 0).toDouble();
                      return shareB.compareTo(shareA);
                    });
                    return list;
                  }()).map((p) {
                    final pd = Map<String, dynamic>.from(p);
                    return TableRow(
                      children: [
                        _buildTableCell(pd['partnerName'] ?? ''),
                        _buildTableCell('EGP ${_formatCurrency(pd['currentCapitalWorth'])}'),
                        _buildTableCell('EGP ${_formatCurrency(pd['profitShare'])}'),
                        _buildTableCell('EGP ${_formatCurrency(pd['salaryShare'])}'),
                        _buildTableCell('EGP ${_formatCurrency(pd['cumulativeTotalShare'])}', isBold: true, color: AppColors.success),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(LucideIcons.image, size: 16),
                label: const Text('Save Image'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                onPressed: () => _processInvoice(action: 'save_image'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(LucideIcons.fileDown, size: 16),
                label: const Text('Export PDF'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                onPressed: () => _processInvoice(action: 'pdf'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(LucideIcons.share2, size: 16),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                onPressed: () => _processInvoice(action: 'share_image'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInvoiceDetailRow(String label, dynamic value, {bool isNegative = false, bool isBold = false, Color? color, double size = 11}) {
    final double val = (value ?? 0).toDouble();
    final bool showAsNegative = isNegative || val < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: size, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${showAsNegative ? "-" : ""}EGP ${_formatCurrency(val.abs())}',
            style: GoogleFonts.inter(
              fontSize: size,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? (showAsNegative ? AppColors.error : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderCell(String label) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTableCell(String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color ?? AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceRow(String label, double value, {bool isNegative = false, bool isBold = false, Color? color, bool isPrimary = false, bool isSecondarySub = false}) {
    final bool showAsNegative = isNegative || value < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isPrimary ? 13 : (isSecondarySub ? 11 : 12),
              fontWeight: (isBold || isPrimary) ? FontWeight.bold : FontWeight.normal,
              color: isPrimary ? AppColors.primaryDark : (isSecondarySub ? AppColors.textMuted : AppColors.textSecondary),
            ),
          ),
          Text(
            '${showAsNegative ? "-" : ""}EGP ${_formatCurrency(value.abs())}',
            style: GoogleFonts.inter(
              fontSize: isPrimary ? 13 : (isSecondarySub ? 11 : 12),
              fontWeight: (isBold || isPrimary) ? FontWeight.bold : FontWeight.w600,
              color: color ?? (showAsNegative ? AppColors.error : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isClosed) {
    if (isClosed) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          if (_currentStage > 0) ...[
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                onPressed: () {
                  setState(() {
                    _currentStage--;
                  });
                },
                child: Text('Previous', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentStage == 3 ? AppColors.success : AppColors.primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              onPressed: _closingInProgress
                  ? null
                  : () {
                      if (_currentStage == 0 && _pendingAuditCount > 0) {
                        _showPendingAuditWarning();
                      } else if (_currentStage < 3) {
                        setState(() {
                          _currentStage++;
                        });
                      } else {
                        _confirmCloseMonth();
                      }
                    },
              child: _closingInProgress
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      _currentStage == 3 ? 'Confirm & Close Month' : 'Next',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
