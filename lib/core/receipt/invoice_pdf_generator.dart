import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/settings_provider.dart';

class InvoicePdfGenerator {
  static Future<void> shareInvoicePdf({
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> items,
    required SettingsProvider settings,
  }) async {
    final pdf = await _generatePdf(
      invoice: invoice,
      items: items,
      settings: settings,
    );
    final invoiceNo = invoice['invoice_no']?.toString() ?? 'invoice';
    final file = await _savePdfToTemp(pdf, invoiceNo);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Bill Invoice $invoiceNo from ${settings.shopName.isEmpty ? AppConstants.shopName : settings.shopName}',
    );
  }

  static Future<pw.Document> _generatePdf({
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> items,
    required SettingsProvider settings,
  }) async {
    final sym = settings.currencySymbol;
    final shopName = settings.shopName.isEmpty ? AppConstants.shopName : settings.shopName;
    final created = DateTime.tryParse(invoice['created_at']?.toString() ?? '') ?? DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(created);
    final timeStr = DateFormat('hh:mm a').format(created);
    final invoiceNo = invoice['invoice_no']?.toString() ?? '';
    final custName = invoice['customer_name']?.toString() ?? 'Walk-in Customer';
    final custPhone = invoice['customer_phone']?.toString() ?? '';

    final total = (invoice['total'] as num?)?.toDouble() ?? 0;
    final paid = (invoice['paid'] as num?)?.toDouble() ?? 0;
    final balance = (invoice['balance'] as num?)?.toDouble() ?? (total - paid);
    final prevBal = (invoice['previous_balance'] as num?)?.toDouble() ?? 0;
    final currBal = (invoice['current_balance'] as num?)?.toDouble() ?? (balance + prevBal);
    final shipping = (invoice['shipping'] as num?)?.toDouble() ?? 0;
    final packaging = (invoice['packaging'] as num?)?.toDouble() ?? 0;
    final deliveryBoyName = invoice['delivery_boy_name']?.toString() ?? '';
    
    double totalQty = 0;
    int totalItemsCount = items.length;
    double subtotal = 0;

    for (var item in items) {
      final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
      final price = (item['price'] as num?)?.toDouble() ?? 0;
      totalQty += qty;
      subtotal += qty * price;
    }

    final pdf = pw.Document();
    pw.MemoryImage? logoImage;

    try {
      final logoData = await rootBundle.load('assets/images/log.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      debugPrint('Failed to load logo for PDF: $e');
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(288, double.infinity, marginAll: 16),
        margin: const pw.EdgeInsets.all(16),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // Logo
              if (logoImage != null) ...[
                pw.Center(
                  child: pw.Image(logoImage, width: 140),
                ),
                pw.SizedBox(height: 12),
              ],

              // Shop Details
              pw.Text(
                AppConstants.shopAddress,
                style: const pw.TextStyle(fontSize: 9),
              ),
              if (AppConstants.shopPhone.isNotEmpty)
                pw.Text(
                  'Ph.No.: ${AppConstants.shopPhone}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              if (AppConstants.shopEmail.isNotEmpty)
                pw.Text(
                  'Email: ${AppConstants.shopEmail}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              pw.SizedBox(height: 12),

              // Title
              pw.Center(
                child: pw.Text(
                  'Bill Invoice',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Divider(thickness: 1),

              // Meta (Invoice No, Date, Time)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Invoice No: $invoiceNo', style: const pw.TextStyle(fontSize: 9)),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Time: $timeStr', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1),

              // Bill To
              pw.Text(
                'Bill To:',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Center(
                child: pw.Text(
                  custName.toUpperCase(),
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Divider(thickness: 1),

              // Items Table
              pw.Column(
                children: [
                  // Header
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Row(
                      children: [
                        pw.SizedBox(width: 30, child: pw.Text('#', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                        pw.Expanded(child: pw.Text('Item Name', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                        pw.SizedBox(width: 60, child: pw.Text('Price', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                        pw.SizedBox(width: 60, child: pw.Text('Amount', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                      ],
                    ),
                  ),
                  pw.Divider(thickness: 1),
                  ...items.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    final name = item['item_name']?.toString() ?? 'Item';
                    final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
                    final price = (item['price'] as num?)?.toDouble() ?? 0;
                    final rawAmt = qty * price;
                    final discPct = (item['discount_percent'] as num?)?.toDouble()
                                 ?? (item['discount'] as num?)?.toDouble()
                                 ?? 0.0;
                    final discAmt = (discPct > 0) ? (rawAmt * discPct / 100) : 0.0;
                    final finalAmt = rawAmt - discAmt;
                    final unit = item['unit']?.toString() ?? '';

                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              pw.SizedBox(width: 30, child: pw.Text('${i + 1}', style: const pw.TextStyle(fontSize: 9))),
                              pw.Expanded(
                                child: pw.Text(name, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.normal)),
                              ),
                              pw.SizedBox(width: 60, child: pw.Text('$sym${price.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                              pw.SizedBox(width: 60, child: pw.Text('$sym${rawAmt.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                            ],
                          ),
                          pw.Row(
                            children: [
                              pw.SizedBox(width: 30),
                              pw.Expanded(
                                child: pw.Text('    ${_qtyStr(qty)}$unit', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
              pw.Divider(thickness: 1),

              // Qty & Items
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Qty: ${_qtyStr(totalQty)}', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('Items: $totalItemsCount', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text('$sym${subtotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Divider(thickness: 1),

              // Totals
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfColonRow('Subtotal', '$sym${_amt(subtotal)}'),
                    if (shipping > 0) _pdfColonRow('Shipping', '$sym${_amt(shipping)}'),
                    if (packaging > 0) _pdfColonRow('Packaging', '$sym${_amt(packaging)}'),
                    _pdfColonRow('Paid', '$sym${_amt(paid)}'),
                    pw.Divider(height: 8, thickness: 1),
                    _pdfColonRow('Total', '$sym${_amt(total)}', bold: true),
                    _pdfColonRow('Balance', '$sym${_amt(balance)}'),
                    _pdfColonRow('Current Bal.', '$sym${_amt(currBal)}'),
                    _pdfColonRow('Previous Bal.', '$sym${_amt(prevBal)}'),
                  ],
                ),
              ),
              pw.Divider(thickness: 1),

              // Terms & Conditions
              pw.Text(
                'Terms & Conditions',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('----', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              pw.SizedBox(height: 16),

              // Received Sign
              pw.Text('....... Received Sign .......', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 4),

              // Delivery by
              if (deliveryBoyName.isNotEmpty)
                pw.Text('Delivery by... $deliveryBoyName', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 4),

              pw.Divider(thickness: 1),

              // Footer
              pw.Center(
                child: pw.Text(
                  'Thank You Visit Again',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.normal,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _pdfColonRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Text(
            '$label :',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Spacer(),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static String _amt(double v) {
    return v.toStringAsFixed(2);
  }

  static Future<File> _savePdfToTemp(pw.Document pdf, String name) async {
    final dir = await getTemporaryDirectory();
    final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File('${dir.path}/${safeName}_godawari.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static String _qtyStr(double qty) {
    if (qty == qty.truncateToDouble()) return qty.toInt().toString();
    return qty.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
}
