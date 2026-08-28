import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:admin_app/core/services/app_image_cache_manager.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:admin_app/core/widgets/app_toast.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:arabic_reshaper/arabic_reshaper.dart';
import 'package:gal/gal.dart';
import 'dart:io';
import 'dart:ui' as ui;

double _toDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? 0.0;
  return 0.0;
}

class InvoiceDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> invoice;

  const InvoiceDetailsScreen({
    super.key,
    required this.invoice,
  });

  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  late Map<String, dynamic> _invoice;
  bool _isLoading = false;
  final _currencyFormat = NumberFormat('#,##0.00', 'en');
  final _dateFormat = DateFormat('dd/MM/yyyy hh:mm a');

  @override
  void initState() {
    super.initState();
    _invoice = Map<String, dynamic>.from(widget.invoice);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInvoiceDetails();
    });
  }

  Future<void> _loadInvoiceDetails() async {
    setState(() => _isLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final res = await client.get('/api/admin/auth/procurement/invoices/${widget.invoice['id']}');
      if (mounted) {
        setState(() {
          _invoice = Map<String, dynamic>.from(res['invoice']);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(
          content: Text('Failed to load invoice details: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _makeCall(String phone) async {
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(
          content: const Text('Could not place call'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri url = Uri.parse('mailto:$email');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(
          content: const Text('Could not open email client'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  // --- PDF & Image Processing ---

  static Future<pw.Document> generatePurchaseInvoicePdf(Map<String, dynamic> invoice) async {
    final pdfDoc = pw.Document();

    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    const primaryColor = PdfColor.fromInt(0xFF12403C);
    const accentColor = PdfColor.fromInt(0xFFD4AF37);
    const textDark = PdfColor.fromInt(0xFF2C3E50);
    const greyColor = PdfColor.fromInt(0xFF7F8C8D);
    const bgColor = PdfColor.fromInt(0xFFFCF8F3);

    // Pre-download product images for the PDF
    final itemsList = invoice['items'] as List? ?? [];
    final Map<int, pw.ImageProvider> itemImages = {};
    for (int i = 0; i < itemsList.length; i++) {
      final item = itemsList[i];
      final String? imageUrl = item['imageUrl'] ??
          item['product']?['imageUrl'] ??
          (item['product']?['images'] is List && (item['product']?['images'] as List).isNotEmpty
              ? (item['product']?['images'] as List).first?.toString()
              : null);
              
      if (imageUrl != null && imageUrl.trim().isNotEmpty && imageUrl.startsWith('http')) {
        try {
          final imageFile = await AppImageCacheManager.instance.getSingleFile(imageUrl.trim());
          itemImages[i] = pw.MemoryImage(await imageFile.readAsBytes());
        } catch (_) {}
      }
    }

    bool hasArabic(String text) {
      return RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(text);
    }

    String reshape(String text) {
      if (hasArabic(text)) {
        return ArabicReshaper.instance.reshape(text);
      }
      return text;
    }

    pw.Widget pdfText(String text, {double size = 9, bool isBold = false, PdfColor? color, pw.TextAlign align = pw.TextAlign.left}) {
      final isAr = hasArabic(text);
      return pw.Text(
        reshape(text),
        textAlign: align,
        textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        style: pw.TextStyle(
          font: isBold ? boldFont : font,
          fontSize: size,
          color: color ?? textDark,
        ),
      );
    }

    pw.Widget infoPdfRow(
      pw.Widget Function(String, {double size, bool isBold, PdfColor? color, pw.TextAlign align}) pdfText,
      String label,
      String val,
    ) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 4,
              child: pdfText('$label:', size: 9, color: greyColor, isBold: true),
            ),
            pw.Expanded(
              flex: 6,
              child: pdfText(val, size: 9, color: textDark),
            ),
          ],
        ),
      );
    }

    final supplierName = invoice['supplier']?['name'] ?? 'Unknown Supplier';
    final supplierContact = invoice['supplier']?['contactPerson'] ?? '-';
    final supplierPhone = invoice['supplier']?['phone'] ?? '-';
    final supplierEmail = invoice['supplier']?['email'] ?? '-';
    final paymentTerms = invoice['supplier']?['paymentTerms'] ?? invoice['paymentTerms'] ?? 'NET30';
    final safeName = invoice['payments'] != null && (invoice['payments'] as List).isNotEmpty
        ? invoice['payments'][0]['reference']?.toString() ?? 'N/A'
        : 'N/A';

    final invoiceNo = invoice['invoiceNumber']?.toString() ?? 'N/A';
    final dateStr = invoice['issueDate'] ?? '';
    final date = DateTime.tryParse(dateStr)?.toLocal() ?? DateTime.now();
    final formattedDate = '${date.day}/${date.month}/${date.year}';
    
    final status = invoice['status'] ?? 'DRAFT';
    final paymentStatus = invoice['paymentStatus'] ?? 'UNPAID';

    final subtotal = _toDouble(invoice['subtotal'] ?? invoice['grandTotal']);
    final tax = _toDouble(invoice['taxTotal']);
    final shipping = _toDouble(invoice['shippingTotal']);
    final discount = _toDouble(invoice['discountTotal']);
    final total = _toDouble(invoice['grandTotal']);
    final notes = invoice['notes'] ?? '';

    pdfDoc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 40),
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font, bold: boldFont),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: bgColor),
          ),
        ),
        build: (pw.Context context) {
          return [
            // Header Banner
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
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
                      pdfText('LegaCy Store', size: 24, isBold: true, color: accentColor),
                      pw.SizedBox(height: 4),
                      pdfText('PURCHASE BILL / INVOICE', size: 12, color: PdfColors.white),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pdfText('BILL #$invoiceNo', size: 16, isBold: true, color: PdfColors.white),
                      pw.SizedBox(height: 6),
                      if (status == 'POSTED' || paymentStatus == 'PAID')
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: const pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFFDCFCE7),
                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Text(
                            'PAID IN FULL',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 10,
                              color: const PdfColor.fromInt(0xFF16A34A),
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: const pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFFFEF3C7),
                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Text(
                            status,
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 10,
                              color: const PdfColor.fromInt(0xFFD97706),
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Info Grid
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: PdfColors.grey200),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pdfText('SUPPLIER DETAILS', size: 10, isBold: true, color: primaryColor),
                        pw.Divider(color: PdfColors.grey200),
                        pw.SizedBox(height: 4),
                        infoPdfRow(pdfText, 'Company Name', supplierName),
                        infoPdfRow(pdfText, 'Contact Person', supplierContact),
                        infoPdfRow(pdfText, 'Phone Number', supplierPhone),
                        infoPdfRow(pdfText, 'Email Address', supplierEmail),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: PdfColors.grey200),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pdfText('BILLING INFORMATION', size: 10, isBold: true, color: primaryColor),
                        pw.Divider(color: PdfColors.grey200),
                        pw.SizedBox(height: 4),
                        infoPdfRow(pdfText, 'Date Issued', formattedDate),
                        infoPdfRow(pdfText, 'Payment Safe', safeName),
                        infoPdfRow(pdfText, 'Payment Terms', paymentTerms),
                        infoPdfRow(pdfText, 'Payment Status', paymentStatus == 'PAID' ? 'PAID' : paymentStatus),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            pdfText('ITEMIZED BREAKDOWN', size: 11, isBold: true, color: primaryColor),
            pw.SizedBox(height: 8),

            pw.Container(
              decoration: const pw.BoxDecoration(
                color: primaryColor,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: pw.Row(
                children: [
                  pw.SizedBox(width: 32), // Align description text with image spacing (24 + 8 gap)
                  pw.Expanded(flex: 4, child: pdfText('ITEM DESCRIPTION', color: PdfColors.white, isBold: true)),
                  pw.Expanded(flex: 1, child: pdfText('QTY', align: pw.TextAlign.right, color: PdfColors.white, isBold: true)),
                  pw.Expanded(flex: 2, child: pdfText('UNIT COST', align: pw.TextAlign.right, color: PdfColors.white, isBold: true)),
                  pw.Expanded(flex: 2, child: pdfText('TOTAL', align: pw.TextAlign.right, color: PdfColors.white, isBold: true)),
                ],
              ),
            ),

            ...List.generate(itemsList.length, (idx) {
              final item = itemsList[idx];
              final name = item['product']?['name'] ?? item['description'] ?? 'Product';
              final qty = item['quantity'] ?? 0;
              final unitCost = _toDouble(item['unitCost']);
              final totalCost = _toDouble(item['totalCost'] ?? (qty * unitCost));
              final img = itemImages[idx];

              return pw.Container(
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: pw.Row(
                  children: [
                    // Small rounded rectangle product image thumbnail
                    pw.Container(
                      margin: const pw.EdgeInsets.only(right: 8),
                      child: pw.ClipRRect(
                        horizontalRadius: 4,
                        verticalRadius: 4,
                        child: pw.Container(
                          width: 24,
                          height: 24,
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.grey200,
                          ),
                          child: img != null
                              ? pw.Image(img, fit: pw.BoxFit.cover)
                              : pw.SizedBox.shrink(),
                        ),
                      ),
                    ),
                    pw.Expanded(flex: 4, child: pdfText(name, size: 9)),
                    pw.Expanded(flex: 1, child: pdfText(qty.toString(), align: pw.TextAlign.right, size: 9)),
                    pw.Expanded(flex: 2, child: pdfText('${unitCost.toStringAsFixed(2)} EGP', align: pw.TextAlign.right, size: 9)),
                    pw.Expanded(flex: 2, child: pdfText('${totalCost.toStringAsFixed(2)} EGP', align: pw.TextAlign.right, size: 9, isBold: true)),
                  ],
                ),
              );
            }),
            pw.SizedBox(height: 16),

            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  flex: 5,
                  child: notes.isNotEmpty
                      ? pw.Container(
                          padding: const pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            border: pw.Border.all(color: PdfColors.grey200),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pdfText('NOTES / INSTRUCTIONS:', size: 8, isBold: true, color: primaryColor),
                              pw.SizedBox(height: 4),
                              pdfText(notes, size: 8, color: greyColor),
                            ],
                          ),
                        )
                      : pw.SizedBox.shrink(),
                ),
                pw.SizedBox(width: 24),
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    children: [
                      _pdfRow(pdfText, 'Purchase Subtotal', subtotal),
                      if (tax > 0) _pdfRow(pdfText, 'Tax Total', tax),
                      if (shipping > 0) _pdfRow(pdfText, 'Shipping & Logistics Cost', shipping),
                      if (discount > 0) _pdfRow(pdfText, 'Discounts', -discount, isDiscount: true),
                      pw.SizedBox(height: 12),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: const pw.BoxDecoration(
                          color: primaryColor,
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pdfText('Grand Total (Paid)', size: 12, isBold: true, color: PdfColors.white),
                            pdfText('EGP ${total.toStringAsFixed(2)}', size: 12, isBold: true, color: accentColor, align: pw.TextAlign.right),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 40),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pdfText('Prepared By:', size: 9, isBold: true, color: greyColor),
                    pw.SizedBox(height: 24),
                    pw.Container(width: 120, height: 0.5, color: PdfColors.grey400),
                    pw.SizedBox(height: 4),
                    pdfText('Accountant / Procurement Officer', size: 8, color: greyColor),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pdfText('Approved By:', size: 9, isBold: true, color: greyColor),
                    pw.SizedBox(height: 24),
                    pw.Container(width: 120, height: 0.5, color: PdfColors.grey400),
                    pw.SizedBox(height: 4),
                    pdfText('Store Manager Signature', size: 8, color: greyColor),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            pw.Center(
              child: pw.Column(
                children: [
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 4),
                  pdfText('LegaCy Store - Procurement Management System', size: 10, isBold: true, color: primaryColor),
                  pw.SizedBox(height: 2),
                  pdfText('Generated automatically for internal financial records. Printed on ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}', size: 8, color: greyColor),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdfDoc;
  }

  static pw.Widget _pdfRow(
    pw.Widget Function(String, {double size, bool isBold, PdfColor? color, pw.TextAlign align}) pdfText,
    String desc,
    double amount, {
    bool isDiscount = false,
  }) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 3, child: pdfText(desc, size: 10)),
          pw.Expanded(
            flex: 2,
            child: pdfText(
              '${amount.toStringAsFixed(2)} EGP',
              size: 10,
              isBold: true,
              color: isDiscount ? PdfColors.green800 : null,
              align: pw.TextAlign.right,
            ),
          ),
        ],
      ),
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

  Future<void> _processInvoiceAction(String action) async {
    final messenger = ScaffoldMessenger.of(context);
    
    // Show a premium overlay loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primaryDark, strokeWidth: 3),
              const SizedBox(width: 16),
              Text(
                'Processing Purchase Bill...',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final pdfDoc = await generatePurchaseInvoicePdf(_invoice);
      final bytes = await pdfDoc.save();
      final billNo = _invoice['invoiceNumber']?.toString() ?? 'unknown';

      // Dismiss dialog
      if (mounted) {
        Navigator.pop(context);
      }

      if (action == 'share_image' || action == 'save_image') {
        final raster = await Printing.raster(bytes, pages: [0], dpi: 300).first;
        final rawPngBytes = await raster.toPng();
        final pngBytes = await _fillImageBackgroundWithWhite(rawPngBytes);
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/PurchaseBill_$billNo.png');
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
                content: const Text('Invoice image saved to gallery!'),
                backgroundColor: AppColors.success,
              ),
            );
          } else {
            messenger.showAppToast(
              AppToast.snackBar(
                content: const Text('Gallery permission denied.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        } else {
          // Share image
          final xFile = XFile(file.path);
          await Share.shareXFiles([xFile], text: 'Purchase Bill #$billNo');
        }
      } else {
        // PDF action (print/preview)
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
          name: 'PurchaseBill_$billNo',
        );
      }
    } catch (e) {
      // Dismiss dialog if visible
      if (mounted) {
        Navigator.pop(context);
      }
      messenger.showAppToast(
        AppToast.snackBar(
          content: Text('Failed to process bill: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // --- Deletion Flow ---

  Future<void> _deleteInvoice() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Invoice',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this purchase invoice? This action is irreversible.',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      await client.delete('/api/admin/auth/procurement/invoices/${_invoice['id']}');
      
      messenger.showAppToast(AppToast.snackBar(
        content: const Text('Invoice deleted successfully'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      if (mounted) {
        Navigator.pop(context, true); // Pop with true to refresh parent
      }
    } catch (e) {
      setState(() => _isLoading = false);
      messenger.showAppToast(AppToast.snackBar(
        content: Text('Error: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _invoice['issueDate'] ?? '';
    final date = DateTime.tryParse(dateStr)?.toLocal() ?? DateTime.now();
    final formattedDate = _dateFormat.format(date);

    final supplier = _invoice['supplier'] ?? {};
    final hasPhone = supplier['phone'] != null && supplier['phone'].toString().trim().isNotEmpty;
    final hasEmail = supplier['email'] != null && supplier['email'].toString().trim().isNotEmpty;

    final subtotal = _toDouble(_invoice['subtotal'] ?? _invoice['grandTotal']);
    final tax = _toDouble(_invoice['taxTotal']);
    final shipping = _toDouble(_invoice['shippingTotal']);
    final discount = _toDouble(_invoice['discountTotal']);
    final total = _toDouble(_invoice['grandTotal']);
    
    final status = _invoice['status'] ?? 'DRAFT';
    final paymentStatus = _invoice['paymentStatus'] ?? 'UNPAID';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.primaryDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Purchase Bill',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.trash2, color: AppColors.error, size: 20),
            onPressed: _deleteInvoice,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryDark))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Bill Overview Header Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bill Number',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _invoice['invoiceNumber'] ?? 'N/A',
                                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _statusBadge(status),
                                const SizedBox(height: 6),
                                _paymentBadge(paymentStatus),
                              ],
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Issue Date',
                                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formattedDate,
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Currency',
                                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _invoice['currency'] ?? 'EGP',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Supplier Details Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryDark.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.building, color: AppColors.primaryDark, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Supplier Information',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _infoRow(LucideIcons.user, 'Company', supplier['name'] ?? 'Unknown Supplier'),
                        const SizedBox(height: 10),
                        _infoRow(LucideIcons.contact, 'Contact', supplier['contactPerson'] ?? '-'),
                        const SizedBox(height: 10),
                        _infoRow(
                          LucideIcons.phone,
                          'Phone',
                          supplier['phone'] ?? '-',
                          onTap: hasPhone ? () => _makeCall(supplier['phone']) : null,
                        ),
                        const SizedBox(height: 10),
                        _infoRow(
                          LucideIcons.mail,
                          'Email',
                          supplier['email'] ?? '-',
                          onTap: hasEmail ? () => _sendEmail(supplier['email']) : null,
                        ),
                        const SizedBox(height: 10),
                        _infoRow(LucideIcons.creditCard, 'Payment Terms', supplier['paymentTerms'] ?? 'NET30', badgeText: supplier['paymentTerms']),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Invoice Items Card
                  if (_invoice['items'] != null && (_invoice['items'] as List).isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryDark.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(LucideIcons.package, color: AppColors.primaryDark, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Invoice Items',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: (_invoice['items'] as List).length,
                            separatorBuilder: (_, __) => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(height: 1),
                            ),
                            itemBuilder: (context, idx) {
                              final item = _invoice['items'][idx];
                              final pName = item['product']?['name'] ?? item['description'] ?? 'Product';
                              final qty = item['quantity'] ?? 0;
                              final unitCost = _toDouble(item['unitCost']);
                              final total = _toDouble(item['totalCost'] ?? (qty * unitCost));

                              final String? imgUrl = item['imageUrl'] ??
                                  item['product']?['imageUrl'] ??
                                  (item['product']?['images'] is List && (item['product']?['images'] as List).isNotEmpty
                                      ? (item['product']?['images'] as List).first?.toString()
                                      : null);

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        border: Border.all(color: AppColors.cardBorder, width: 1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: imgUrl != null && imgUrl.trim().isNotEmpty
                                          ? CachedNetworkImage(
                                              cacheManager: AppImageCacheManager.instance,
                                              imageUrl: imgUrl,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(
                                                color: AppColors.background,
                                                child: const Center(
                                                  child: SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryDark),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              errorWidget: (context, url, error) => const Icon(
                                                LucideIcons.package,
                                                color: AppColors.textMuted,
                                                size: 20,
                                              ),
                                            )
                                          : const Icon(
                                              LucideIcons.package,
                                              color: AppColors.textMuted,
                                              size: 20,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pName,
                                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Qty: $qty × EGP ${_currencyFormat.format(unitCost)}',
                                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'EGP ${_currencyFormat.format(total)}',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 4. Costs breakdown Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryDark.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.coins, color: AppColors.primaryDark, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Cost Breakdown',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _costRow('Goods Subtotal', subtotal),
                        if (tax > 0) ...[
                          const SizedBox(height: 12),
                          _costRow('Tax Total', tax),
                        ],
                        if (shipping > 0) ...[
                          const SizedBox(height: 12),
                          _costRow('Shipping & Freight', shipping),
                        ],
                        if (discount > 0) ...[
                          const SizedBox(height: 12),
                          _costRow('Discounts Applied', -discount, isDiscount: true),
                        ],
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(height: 1),
                        ),
                        _costRow('Grand Total (Paid)', total, isGrand: true),
                        if (_invoice['payments'] != null && (_invoice['payments'] as List).isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _costRow(
                            'Paid from Safe',
                            0.0,
                            isSafeName: true,
                            safeNameText: _invoice['payments'][0]['reference']?.toString(),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 5. Notes Section
                  if (_invoice['notes'] != null && _invoice['notes'].toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.stickyNote, size: 18, color: AppColors.primaryDark),
                              const SizedBox(width: 8),
                              Text(
                                'Invoice Notes',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _invoice['notes'],
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(LucideIcons.printer, size: 18, color: Colors.white),
                label: const Text('Print / PDF'),
                onPressed: () => _processInvoiceAction('pdf'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.cardBorder),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(LucideIcons.download, color: AppColors.textPrimary, size: 20),
                onPressed: () => _processInvoiceAction('save_image'),
                tooltip: 'Save Image',
                padding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.cardBorder),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(LucideIcons.share, color: AppColors.textPrimary, size: 20),
                onPressed: () => _processInvoiceAction('share_image'),
                tooltip: 'Share Image',
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {VoidCallback? onTap, String? badgeText}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        ),
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: onTap != null ? AppColors.primaryDark : AppColors.textPrimary,
                decoration: onTap != null ? TextDecoration.underline : TextDecoration.none,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (badgeText != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeText,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _costRow(String desc, double val, {bool isDiscount = false, bool isGrand = false, bool isDebt = false, bool isSafeName = false, String? safeNameText}) {
    Color valColor = AppColors.textPrimary;
    var style = GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary);
    var valStyle = GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary);

    if (isDiscount) {
      valColor = AppColors.success;
      valStyle = GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: valColor);
    } else if (isGrand) {
      style = GoogleFonts.playfairDisplay(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primaryDark);
      valStyle = GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF8B5CF6));
    } else if (isDebt) {
      valColor = val > 0 ? AppColors.error : AppColors.success;
      valStyle = GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: valColor);
      style = GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: valColor);
    } else if (isSafeName) {
      valColor = AppColors.primaryDark;
      valStyle = GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: valColor);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(desc, style: style),
        Text(
          isSafeName ? (safeNameText ?? '-') : 'EGP ${_currencyFormat.format(val)}',
          style: valStyle,
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    final color = status == 'POSTED' ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(status, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }

  Widget _paymentBadge(String status) {
    final color = status == 'PAID' ? AppColors.success : (status == 'PARTIAL' ? AppColors.warning : AppColors.error);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(status, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }
}
