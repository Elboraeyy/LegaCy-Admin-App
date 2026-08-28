import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/widgets/app_toast.dart';
import 'package:admin_app/core/services/app_image_cache_manager.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:arabic_reshaper/arabic_reshaper.dart';
import 'package:gal/gal.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';

class OrderActionsHelper {
  static String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static Future<pw.Document> generateInvoicePdf(Map<String, dynamic> order) async {
    final pdfDoc = pw.Document();

    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    const primaryColor = PdfColor.fromInt(0xFF12403C);
    const accentColor = PdfColor.fromInt(0xFFD4AF37);
    const bgColor = PdfColor.fromInt(0xFFFCF8F3);

    String reshape(String text) => ArabicReshaper.instance.reshape(text);

    String safeString(dynamic val) {
      if (val == null) return '';
      if (val is List) {
        return val
            .map((e) {
              if (e is Map) return e['content']?.toString() ?? '';
              return e.toString();
            })
            .where((e) => e.toString().trim().isNotEmpty)
            .join(' - ');
      }
      if (val is Map) return val['content']?.toString() ?? '';
      return val.toString();
    }

    final name = reshape(
      safeString(
        order['displayName'] ?? order['customer']?['name'] ?? 'Customer',
      ),
    );
    final phone = safeString(
      order['phone'] ??
          order['shippingPhone'] ??
          order['customerPhone'] ??
          order['phoneNumber'] ??
          order['customer']?['phone'],
    );

    final shippingAddrObj = order['shippingAddress'] is Map
        ? order['shippingAddress']
        : null;
    final shippingAddrStr = order['shippingAddress'] is String
        ? order['shippingAddress']
        : '';
    final rawAddress = safeString(
      shippingAddrStr.isNotEmpty
          ? shippingAddrStr
          : (shippingAddrObj?['address'] ?? order['address']),
    );

    final rawGov = safeString(
      shippingAddrObj?['governorate'] ??
          shippingAddrObj?['state'] ??
          order['shippingGovernorate'] ??
          order['governorate'] ??
          order['customer']?['governorate'],
    );
    final rawCity = safeString(
      shippingAddrObj?['city'] ??
          order['shippingCity'] ??
          order['city'] ??
          order['customer']?['city'],
    );

    final List<String> addressParts = [];
    if (rawGov.isNotEmpty) addressParts.add(rawGov);
    if (rawCity.isNotEmpty) addressParts.add(rawCity);
    if (rawAddress.isNotEmpty) addressParts.add(rawAddress);
    final fullAddress = reshape(addressParts.join(' - '));

    final altPhone = safeString(
      order['alternativePhone'] ??
          order['altPhone'] ??
          order['customer']?['alternativePhone'],
    );

    final orderNo = order['orderNumber']?.toString() ?? 'N/A';
    final items = (order['items'] as List? ?? []);

    final Map<int, pw.ImageProvider> itemImages = {};
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final imageUrl = item['product']?['imageUrl'] ?? item['imageUrl'];
      if (imageUrl != null && imageUrl.toString().startsWith('http')) {
        try {
          final imageFile = await AppImageCacheManager.instance.getSingleFile(
            imageUrl.toString(),
          );
          itemImages[i] = pw.MemoryImage(await imageFile.readAsBytes());
        } catch (_) {}
      }
    }

    final subtotal = (order['subtotal'] as num?)?.toDouble() ?? 0.0;
    final shipping = (order['shippingCost'] as num?)?.toDouble() ?? 0.0;
    final total = (order['totalPrice'] as num?)?.toDouble() ?? 0.0;

    double discount = (order['discount'] as num?)?.toDouble() ?? 0.0;
    if (discount <= 0) {
      double diff = (subtotal + shipping) - total;
      if (diff > 0.5) discount = diff;
    }

    final paymentMethod = order['paymentMethod'] ?? 'COD';
    final orderDate = _formatDate(order['createdAt']);

    pw.Widget buildInfoRow(
      String label,
      String value, {
      bool isRtl = false,
      bool isBold = false,
    }) {
      if (value.toString().trim().isEmpty) return pw.SizedBox();
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 80,
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 12,
                  color: primaryColor,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                value.toString(),
                textAlign: pw.TextAlign.left,
                textDirection: isRtl
                    ? pw.TextDirection.rtl
                    : pw.TextDirection.ltr,
                style: pw.TextStyle(
                  fontSize: 12,
                  color: isBold ? primaryColor : PdfColors.grey800,
                  fontWeight: isBold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );
    }

    pdfDoc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 48),
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font, bold: boldFont),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: bgColor),
          ),
        ),
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(24),
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
                      pw.Text(
                        'LegaCy',
                        style: pw.TextStyle(
                          color: accentColor,
                          fontSize: 32,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Premium Watches',
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        '#$orderNo',
                        style: pw.TextStyle(color: accentColor, fontSize: 18),
                      ),
                      pw.Text(
                        'Date: $orderDate',
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 32),

            // Customer Info & Payment Method
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'BILLED TO:',
                  style: pw.TextStyle(
                    color: primaryColor,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: buildInfoRow(
                        'Name:',
                        name,
                        isRtl: true,
                        isBold: true,
                      ),
                    ),
                    pw.Expanded(
                      child: buildInfoRow(
                        'Payment:',
                        paymentMethod.toString().toUpperCase(),
                        isBold: true,
                      ),
                    ),
                  ],
                ),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(child: buildInfoRow('Phone:', phone)),
                    pw.Expanded(
                      child: buildInfoRow('Alt Phone:', altPhone.toString()),
                    ),
                  ],
                ),
                buildInfoRow('Address:', fullAddress, isRtl: true),
              ],
            ),
            pw.SizedBox(height: 32),

            // Table Header
            pw.Container(
              decoration: pw.BoxDecoration(
                color: bgColor,
                border: const pw.Border(
                  bottom: pw.BorderSide(color: primaryColor, width: 2),
                ),
              ),
              padding: const pw.EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 8,
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                      'ITEM',
                      style: pw.TextStyle(
                        color: primaryColor,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'QTY',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: primaryColor,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'PRICE',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        color: primaryColor,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'TOTAL',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        color: primaryColor,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Table Items
            ...items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final qty = item['quantity'] ?? 1;
              final price = (item['price'] as num?)?.toDouble() ?? 0.0;
              final itemTotal = price * qty;

              String cleanItemName = item['name']?.toString() ?? '';
              cleanItemName = cleanItemName
                  .replaceAll(RegExp(r'\s*\([^)]*\)$'), '')
                  .trim();
              final itemName = reshape(cleanItemName);
              return pw.Container(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                  ),
                ),
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Expanded(
                      flex: 4,
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          if (itemImages[i] != null) ...[
                            pw.Container(
                              width: 24,
                              height: 24,
                              decoration: pw.BoxDecoration(
                                borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(4),
                                ),
                                image: pw.DecorationImage(
                                  image: itemImages[i]!,
                                  fit: pw.BoxFit.cover,
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 8),
                          ],
                          pw.Expanded(
                            child: pw.Text(
                              itemName,
                              textDirection: pw.TextDirection.rtl,
                              style: const pw.TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        qty.toString(),
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        '${price.toStringAsFixed(2)} EGP',
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        '${itemTotal.toStringAsFixed(2)} EGP',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            pw.SizedBox(height: 24),

            // Summary
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 250,
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Subtotal',
                            style: const pw.TextStyle(fontSize: 14),
                          ),
                          pw.Text(
                            '${subtotal.toStringAsFixed(2)} EGP',
                            style: const pw.TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Shipping',
                            style: const pw.TextStyle(fontSize: 14),
                          ),
                          pw.Text(
                            '${shipping.toStringAsFixed(2)} EGP',
                            style: const pw.TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      if (discount > 0) ...[
                        pw.SizedBox(height: 8),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Discount',
                              style: pw.TextStyle(
                                fontSize: 14,
                                color: primaryColor,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              '-${discount.toStringAsFixed(2)} EGP',
                              style: pw.TextStyle(
                                fontSize: 14,
                                color: primaryColor,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                      pw.SizedBox(height: 12),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: const pw.BoxDecoration(
                          color: primaryColor,
                          borderRadius: pw.BorderRadius.all(
                            pw.Radius.circular(8),
                          ),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Total',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              '${total.toStringAsFixed(2)} EGP',
                              style: pw.TextStyle(
                                color: accentColor,
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 48),

            // Footer
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'Thank you for shopping with LegaCy!',
                    style: pw.TextStyle(
                      color: primaryColor,
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Please note that a 14-day exchange and return policy applies to all orders in case of any issues.',
                    style: const pw.TextStyle(
                      color: PdfColors.grey600,
                      fontSize: 10,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'For inquiries, please contact us on WhatsApp.',
                    style: const pw.TextStyle(
                      color: PdfColors.grey600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );
    return pdfDoc;
  }

  static Future<void> processInvoice(
    BuildContext context,
    Map<String, dynamic> order, {
    required String action,
    Future<Map<String, dynamic>>? fullOrderFuture,
  }) async {
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
                'Generating PDF Statement...',
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
      final resolvedOrder = fullOrderFuture != null ? await fullOrderFuture : order;
      final pdfDoc = await generateInvoicePdf(resolvedOrder);
      final bytes = await pdfDoc.save();
      final orderNo = resolvedOrder['orderNumber']?.toString() ?? 'unknown';

      // Dismiss dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (action == 'share_image' || action == 'save_image') {
        final raster = await Printing.raster(bytes, pages: [0], dpi: 300).first;
        final rawPngBytes = await raster.toPng();
        final pngBytes = await _fillImageBackgroundWithWhite(rawPngBytes);
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/Invoice_$orderNo.png');
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
                content: const Text('Image saved to gallery successfully!'),
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
          // Share image
          final xFile = XFile(file.path);
          await Share.shareXFiles([xFile], text: 'Invoice for Order #$orderNo');
        }
      } else {
        // PDF action (print/preview)
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
          name: 'Invoice_$orderNo',
        );
      }
    } catch (e) {
      // Dismiss dialog if visible
      if (context.mounted) {
        Navigator.pop(context);
      }
      messenger.showAppToast(
        AppToast.snackBar(
          content: Text('Failed to process invoice: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  static String _getWhatsAppMessageText(Map<String, dynamic> order) {
    final status = order['status']?.toString().toLowerCase() ?? 'pending';

    final name = order['displayName'] ?? order['customer']?['name'] ?? 'Customer';
    final orderNo = order['orderNumber']?.toString() ?? '';
    final total = (order['totalPrice'] as num?)?.toDouble() ?? 0.0;
    final shipping = (order['shippingCost'] as num?)?.toDouble() ?? 0.0;

    if (status == 'delivered' || status == 'cash_received') {
      return '''مرحبًا $name ✨
نتمنى إن طلبك من LegaCy وصلك بأمان وبالشكل اللي كنت متوقعه.
يسعدنا جدًا نسمع رأيك.
ولو عندك أي ملاحظة أو استفسار، يشرفنا تواصلك معنا.
شكرًا لثقتك بنا 💚''';
    } else if (status == 'shipped' || status == 'out_for_delivery') {
      return '''مرحبًا $name ✨
طلبك رقم #$orderNo من LegaCy خرج للشحن وفي طريقه ليك! 🚚
قيمة الطلب: $total EGP
المندوب هيتواصل معاك قريب جداً للتسليم.
لو عندك أي استفسار، إحنا دايماً معاك 💚''';
    } else if (status == 'preparing') {
      return '''مرحبًا $name ✨
طلبك رقم #$orderNo من LegaCy قيد التجهيز حالياً! ⏳
بنجاهزه بكل حب واهتمام عشان يوصلك في أحسن صورة.
هنبلغك أول ما يخرج للشحن.
شكرًا لثقتك بنا 💚''';
    } else if (status == 'cancelled' || status == 'payment_failed') {
      return '''مرحبًا $name ✨
تم إلغاء طلبك رقم #$orderNo من LegaCy.
نتمنى نشوفك تاني قريب وتكون جزء من عيلتنا 💚
لو حابب تستفسر عن أي حاجة، إحنا موجودين دايماً!''';
    } else if (status == 'refunded') {
      return '''مرحبًا $name ✨
تم استرجاع طلبك رقم #$orderNo بنجاح، وتمت عملية الـ Refund للرصيد المستحق.
نتمنى نشوفك تاني قريب وتكون جزء من عيلة LegaCy 💚
لو حابب تستفسر عن أي حاجة، إحنا موجودين دايماً!''';
    } else {
      // Pending / Confirmed / Processing
      final items = (order['items'] as List? ?? []);
      String itemsText = '';
      for (int i = 0; i < items.length; i++) {
        String itemName = items[i]['name']?.toString() ?? '';
        itemName = itemName.replaceAll(RegExp(r'\s*\([^)]*\)$'), '').trim();
        if (i == 0) {
          itemsText += '⌚ Watch : $itemName';
        } else {
          itemsText += '\n                     $itemName';
        }
      }

      String shippingText = shipping <= 0
          ? 'Free Shipping'
          : '$shipping EGP Shipping';

      final shippingAddrObj = order['shippingAddress'] is Map
          ? order['shippingAddress']
          : null;
      final shippingAddrStr = order['shippingAddress'] is String
          ? order['shippingAddress']
          : '';
      final address = shippingAddrStr.isNotEmpty
          ? shippingAddrStr
          : (shippingAddrObj?['address'] ?? order['address'] ?? '');
      final gov =
          shippingAddrObj?['governorate'] ??
          shippingAddrObj?['state'] ??
          order['shippingGovernorate'] ??
          order['governorate'] ??
          order['customer']?['governorate'] ??
          '';
      final city =
          shippingAddrObj?['city'] ??
          order['shippingCity'] ??
          order['city'] ??
          order['customer']?['city'] ??
          '';

      final List<String> addressParts = [];
      if (gov.toString().isNotEmpty) addressParts.add(gov.toString());
      if (city.toString().isNotEmpty) addressParts.add(city.toString());
      if (address.toString().isNotEmpty) addressParts.add(address.toString());
      final fullAddress = addressParts.join(' ، ');

      final phone1 =
          order['phone'] ??
          order['shippingPhone'] ??
          order['customerPhone'] ??
          order['phoneNumber'] ??
          order['customer']?['phone'] ??
          '';
      final phone2 =
          order['alternativePhone'] ??
          order['altPhone'] ??
          order['customer']?['alternativePhone'] ??
          '';

      return '''Thank you for choosing LegaCy 💚

Order : #$orderNo
Name : $name
$itemsText
💰 Total Due : EGP $total + $shippingText
📍 Address : $fullAddress
Delivered in (1 : 4) Days
Phone 1 : $phone1${phone2.toString().trim().isNotEmpty ? '\nPhone 2 : $phone2' : ''}

Thanks for shopping with us! 💚''';
    }
  }

  static Future<void> shareViaWhatsApp(BuildContext context, Map<String, dynamic> order) async {
    final phone =
        order['phone'] ??
        order['shippingPhone'] ??
        order['customerPhone'] ??
        order['phoneNumber'] ??
        order['customer']?['phone'] ??
        '';
    final text = _getWhatsAppMessageText(order);

    String formattedPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '2$formattedPhone'; // Egypt country code fallback
    }

    final url =
        "https://wa.me/$formattedPhone?text=${Uri.encodeComponent(text)}";

    if (Platform.isAndroid) {
      try {
        final intent = AndroidIntent(
          action: 'action_view',
          data: url,
          package: 'com.whatsapp.w4b', // Force WhatsApp Business
        );
        await intent.launch();
      } catch (e) {
        if (context.mounted) {
          _launchWhatsAppFallback(context, url);
        }
      }
    } else {
      _launchWhatsAppFallback(context, url);
    }
  }

  static Future<void> _launchWhatsAppFallback(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bool launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
      } catch (e2) {
        messenger.showAppToast(
          AppToast.snackBar(
            content: const Text('WhatsApp is not installed or supported.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  static void showPrintOptions(
    BuildContext context,
    Map<String, dynamic> order, {
    Future<Map<String, dynamic>>? fullOrderFuture,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Invoice Options',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              _buildOptionTile(
                icon: LucideIcons.fileText,
                title: 'Export as PDF',
                subtitle: 'Save or share as a PDF document',
                onTap: () {
                  Navigator.pop(context);
                  processInvoice(context, order, action: 'pdf', fullOrderFuture: fullOrderFuture);
                },
              ),
              const SizedBox(height: 16),
              _buildOptionTile(
                icon: LucideIcons.share,
                title: 'Share Image',
                subtitle: 'Share invoice via WhatsApp or others',
                onTap: () {
                  Navigator.pop(context);
                  processInvoice(context, order, action: 'share_image', fullOrderFuture: fullOrderFuture);
                },
              ),
              const SizedBox(height: 16),
              _buildOptionTile(
                icon: LucideIcons.download,
                title: 'Save Image',
                subtitle: 'Save invoice directly to phone gallery',
                onTap: () {
                  Navigator.pop(context);
                  processInvoice(context, order, action: 'save_image', fullOrderFuture: fullOrderFuture);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  static Future<Uint8List> _fillImageBackgroundWithWhite(Uint8List pngBytes) async {
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
}
