import 'dart:io';
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
    final invoiceNo = invoice['invoice_no']?.toString() ?? '';
    final custName = invoice['customer_name']?.toString() ?? 'Walk-in Customer';
    final custPhone = invoice['customer_phone']?.toString() ?? '';

    final total = (invoice['total'] as num?)?.toDouble() ?? 0;
    final paid = (invoice['paid'] as num?)?.toDouble() ?? 0;
    final balance = (invoice['balance'] as num?)?.toDouble() ?? (total - paid);
    final prevBal = (invoice['previous_balance'] as num?)?.toDouble() ?? 0;
    final currBal = (invoice['current_balance'] as num?)?.toDouble() ?? (balance + prevBal);
    final deliveryBoyName = invoice['delivery_boy_name']?.toString() ?? '';
    
    int totalItemsCount = items.length;
    double totalDiscAmt = 0;

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(16),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Shop Name
              pw.Text(
                shopName.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                AppConstants.shopTagline,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
              if (settings.shopAddress.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  settings.shopAddress,
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  textAlign: pw.TextAlign.center,
                ),
              ],
              if (settings.shopPhone.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'Ph: ${settings.shopPhone}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
              pw.Divider(thickness: 1),

              // Title
              pw.Text(
                'Bill Invoice',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(thickness: 1),

              // Meta
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Invoice No: $invoiceNo', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Divider(thickness: 1),

              // Customer
              pw.Text(
                custName,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              if (custPhone.isNotEmpty)
                pw.Text('Ph: $custPhone', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center),
              pw.Divider(thickness: 1),

              // Items Table (Exact Vyapar format)
              pw.Column(
                children: [
                  // Header
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Row(
                      children: [
                        pw.SizedBox(width: 20, child: pw.Text('#', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                        pw.Expanded(child: pw.Text('Item Name', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                        pw.SizedBox(width: 50, child: pw.Text('Price', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                        pw.SizedBox(width: 50, child: pw.Text('Amount', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
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
                    
                    totalDiscAmt += discAmt;

                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              pw.SizedBox(width: 20, child: pw.Text('${i + 1}', style: const pw.TextStyle(fontSize: 10))),
                              pw.Expanded(
                                child: pw.Text(name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.normal)),
                              ),
                              pw.SizedBox(width: 50, child: pw.Text('$sym${price.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                              pw.SizedBox(width: 50, child: pw.Text('$sym${rawAmt.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                            ],
                          ),
                          pw.Row(
                            children: [
                              pw.SizedBox(width: 20),
                              pw.Expanded(
                                child: pw.Text('    ${_qtyStr(qty)}$unit', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                              ),
                            ],
                          ),
                          if (discPct > 0 && discAmt > 0) ...[
                            pw.Row(
                              children: [
                                pw.SizedBox(width: 20),
                                pw.Expanded(
                                  child: pw.Text('    Disc.(${discPct.toStringAsFixed(0)}%)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                                ),
                                pw.SizedBox(width: 50, child: pw.Text(':', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600), textAlign: pw.TextAlign.right)),
                                pw.SizedBox(width: 50, child: pw.Text('-$sym${_amt(discAmt)}', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                              ],
                            ),
                            pw.Row(
                              children: [
                                pw.SizedBox(width: 20),
                                pw.Expanded(
                                  child: pw.Text('    Final Amount', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                                ),
                                pw.SizedBox(width: 50, child: pw.Text(':', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600), textAlign: pw.TextAlign.right)),
                                pw.SizedBox(width: 50, child: pw.Text('$sym${_amt(finalAmt)}', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
              pw.Divider(thickness: 1),

              // Totals (Exact Vyapar format)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfColonRow('Total', '$totalItemsCount'),
                    if (totalDiscAmt > 0) _pdfColonRow('Total Disc.', '-$sym ${_amt(totalDiscAmt)}'),
                    pw.Divider(height: 8, thickness: 1),
                    _pdfColonRow('Total', '$sym ${_amt(total)}', bold: true),
                    if (settings.printReceivedAmount) _pdfColonRow('Received', '$sym ${_amt(paid)}'),
                    if (settings.printBalanceAmount) _pdfColonRow('Balance', '$sym ${_amt(balance)}'),
                    if (prevBal != 0) _pdfColonRow('Previous Bal.', '$sym ${_amt(prevBal)}'),
                    if (currBal != 0) _pdfColonRow('Current Bal.', '$sym ${_amt(currBal)}', bold: true),
                  ],
                ),
              ),
              pw.Divider(thickness: 1),

              // You Saved section
              if (totalDiscAmt > 0) ...[
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: _pdfColonRow('You Saved', '$sym ${_amt(totalDiscAmt)}', bold: true),
                ),
                pw.Divider(thickness: 1),
              ],

              // Signature
              if (settings.printSignature) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Container(width: 80, height: 1, color: PdfColors.black),
                        pw.SizedBox(height: 2),
                        pw.Text('Received Sign', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Container(width: 80, height: 1, color: PdfColors.black),
                        pw.SizedBox(height: 2),
                        pw.Text('Auth. Sign', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ],
                ),
                pw.Divider(thickness: 1),
              ],

              // Delivery Boy
              if (deliveryBoyName.isNotEmpty) ...[
                pw.Text(
                  'Delivery by: $deliveryBoyName',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 8),
              ],

              // Footer
              pw.SizedBox(height: 8),
              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Thank You Visit Again',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Fresh to your kitchen - Fish, Sea food, Chicken, Mutton',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
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
          pw.SizedBox(width: 30),
          pw.Text(
            '$label :',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Spacer(),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
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
