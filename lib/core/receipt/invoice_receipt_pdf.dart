import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../providers/settings_provider.dart';

class InvoiceReceiptPdf {
  static Future<Uint8List> build({
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> items,
    required SettingsProvider settings,
    String logoAssetPath = 'assets/images/log.png',
  }) async {
    final money = NumberFormat('#,##,##0.00', 'en_IN');
    final scale = settings.receiptFontSize.clamp(0.85, 1.35);
    double fs(double size) => size * scale;

    final created =
        DateTime.tryParse(invoice['created_at']?.toString() ?? '') ??
            DateTime.now();
    final dueDate = DateTime.tryParse(invoice['due_date']?.toString() ?? '') ??
        created.add(Duration(days: settings.dueDateDays));
    final dateStr = DateFormat('dd/MM/yyyy').format(created);
    final timeStr = DateFormat('hh:mm a').format(created);
    final dueDateStr = DateFormat('dd-MM-yyyy').format(dueDate);

    final invoiceNo = invoice['invoice_no']?.toString().trim() ?? '';
    final customerName =
        invoice['customer_name']?.toString().trim().isNotEmpty == true
            ? invoice['customer_name'].toString().trim()
            : 'Walk-in Customer';
    final customerPhone = invoice['customer_phone']?.toString().trim() ?? '';

    // FIX: extract delivery boy name from notes
    final notes = invoice['notes']?.toString().trim() ?? '';
    final deliveryMatch = RegExp(r'Delivery:\s*([^|]+)').firstMatch(notes);
    final deliveryName = deliveryMatch?.group(1)?.trim() ?? '';

    final subtotal = (invoice['subtotal'] as num?)?.toDouble() ?? 0;
    // FIX: discount was missing
    final discount = (invoice['discount'] as num?)?.toDouble() ?? 0;
    final shipping = (invoice['shipping'] as num?)?.toDouble() ?? 0;
    final packaging = (invoice['packaging'] as num?)?.toDouble() ?? 0;
    final total = (invoice['total'] as num?)?.toDouble() ??
        (subtotal - discount + shipping + packaging);
    // FIX: paid was missing
    final paid = (invoice['paid'] as num?)?.toDouble() ?? 0;
    final balance = (invoice['balance'] as num?)?.toDouble() ?? (total - paid);
    final prevBal = (invoice['previous_balance'] as num?)?.toDouble() ?? 0;
    final curBal = (invoice['current_balance'] as num?)?.toDouble() ?? balance;

    final totalQty = items.fold<double>(
      0,
      (sum, row) => sum + ((row['quantity'] as num?)?.toDouble() ?? 0),
    );

    final normalizedShopName = settings.shopName.trim().isEmpty
        ? 'GODAWARI FISH'
        : settings.shopName.trim();
    final normalizedUpiId = settings.upiId.trim();
    final upiQr = normalizedUpiId.isEmpty
        ? ''
        : 'upi://pay?pa=$normalizedUpiId'
            '&pn=${Uri.encodeComponent(normalizedShopName)}'
            '&am=${total.toStringAsFixed(2)}'
            '&cu=INR'
            '&tn=${Uri.encodeComponent('Invoice $invoiceNo')}';

    pw.MemoryImage? logoImage;
    if (settings.printLogo) {
      try {
        final data = await rootBundle.load(logoAssetPath);
        logoImage = pw.MemoryImage(data.buffer.asUint8List());
      } catch (_) {}
    }

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        build: (_) {
          return pw.Center(
            child: pw.Container(
              width: 220,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  if (logoImage != null) ...[
                    pw.Center(
                      child: pw.Image(
                        logoImage,
                        width: 200,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                  ],
                  if (!settings.printLogo && settings.printShopName)
                    pw.Text(
                      normalizedShopName.toUpperCase(),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: fs(18),
                        color: PdfColors.black,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  if (!settings.printLogo) ...[
                    pw.SizedBox(height: 2),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.black,
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                      child: pw.Text(
                        'The Real Taste Of Fresh Fish',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: fs(7.8),
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 6),
                  if (settings.printShopAddress &&
                      settings.shopAddress.trim().isNotEmpty)
                    pw.Text(
                      settings.shopAddress.trim(),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          fontSize: fs(8.5), color: PdfColors.black),
                    ),
                  if (settings.printShopPhone &&
                      settings.shopPhone.trim().isNotEmpty)
                    pw.Text(
                      'Ph.No.: ${settings.shopPhone.trim()}',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          fontSize: fs(8.5), color: PdfColors.black),
                    ),
                  if (settings.printShopEmail &&
                      settings.shopEmail.trim().isNotEmpty)
                    pw.Text(
                      'Email: ${settings.shopEmail.trim()}',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          fontSize: fs(8.2), color: PdfColors.black),
                    ),
                  if (settings.printGstin && settings.gstNo.isNotEmpty)
                    pw.Text(
                      'GSTIN: ${settings.gstNo.trim()}',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          fontSize: fs(8.2), color: PdfColors.black),
                    ),
                  pw.SizedBox(height: 6),
                  _rule(),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Text(
                      settings.printBillOfSupply
                          ? 'Bill of Supply'
                          : 'Tax Invoice',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: fs(10),
                        color: PdfColors.black,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  _rule(),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _metaText(
                              'Invoice No: $invoiceNo',
                              fs(8.6),
                              bold: true,
                            ),
                            _metaText('Due Date: $dueDateStr', fs(8.6)),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            _metaText(
                              'Date: $dateStr',
                              fs(8.6),
                              bold: true,
                              align: pw.TextAlign.right,
                            ),
                            _metaText(
                              'Time: $timeStr',
                              fs(8.6),
                              align: pw.TextAlign.right,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  _rule(),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    customerName,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: fs(10),
                      color: PdfColors.black,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (customerPhone.isNotEmpty)
                    pw.Text(
                      'Ph.No.: $customerPhone',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          fontSize: fs(8.6), color: PdfColors.black),
                    ),
                  pw.SizedBox(height: 4),
                  _rule(),
                  pw.SizedBox(height: 4),
                  pw.Table(
                    border: const pw.TableBorder(
                      horizontalInside: pw.BorderSide(
                        color: PdfColors.grey300,
                        width: 0.35,
                      ),
                    ),
                    columnWidths: {
                      if (settings.printSNo) 0: const pw.FixedColumnWidth(16),
                      1: const pw.FlexColumnWidth(3.3),
                      if (settings.printMrp) 2: const pw.FlexColumnWidth(1.2),
                      3: const pw.FlexColumnWidth(1.6),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(
                              color: PdfColors.grey500,
                              width: 0.45,
                            ),
                          ),
                        ),
                        children: [
                          if (settings.printSNo)
                            _headerCell('#', fs(8.6), pw.TextAlign.left),
                          _headerCell(
                              'Item Name${settings.printUnit ? '\nQuantity' : ''}',
                              fs(8.6),
                              pw.TextAlign.left),
                          if (settings.printMrp)
                            _headerCell('Price', fs(8.6), pw.TextAlign.right),
                          _headerCell('Amount', fs(8.6), pw.TextAlign.right),
                        ],
                      ),
                      ...items.asMap().entries.map((entry) {
                        final index = entry.key + 1;
                        final row = entry.value;
                        final qty = (row['quantity'] as num?)?.toDouble() ?? 0;
                        final unit =
                            row['unit']?.toString().trim().isNotEmpty == true
                                ? row['unit'].toString().trim()
                                : 'Kg';
                        final price = (row['price'] as num?)?.toDouble() ?? 0;
                        final amount = (row['amount'] as num?)?.toDouble() ?? 0;
                        final itemName =
                            row['item_name']?.toString().trim() ?? 'Item';
                        return pw.TableRow(
                          children: [
                            if (settings.printSNo)
                              _valueCell('$index', fs(8.6)),
                            _valueCell(
                              '$itemName${settings.printUnit ? '\n${_formatQty(qty)}$unit' : ''}',
                              fs(8.8),
                              bold: true,
                            ),
                            if (settings.printMrp)
                              _valueCell(
                                price.toStringAsFixed(
                                    settings.printAmountWithDecimal ? 2 : 0),
                                fs(8.6),
                                align: pw.TextAlign.right,
                              ),
                            _valueCell(
                              amount.toStringAsFixed(
                                  settings.printAmountWithDecimal ? 2 : 0),
                              fs(8.6),
                              bold: true,
                              align: pw.TextAlign.right,
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                  pw.SizedBox(height: 5),
                  _rule(),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      if (settings.printTotalQuantity)
                        pw.Text(
                          'Qty: ${_formatQty(totalQty)}',
                          style: pw.TextStyle(
                            fontSize: fs(8.8),
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      pw.Text(
                        'Items: ${items.length}',
                        style: pw.TextStyle(
                          fontSize: fs(8.8),
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        subtotal.toStringAsFixed(
                            settings.printAmountWithDecimal ? 2 : 0),
                        style: pw.TextStyle(
                          fontSize: fs(8.8),
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  _rule(),
                  pw.SizedBox(height: 5),

                  // ── Totals ──────────────────────────────────────────
                  // Show subtotal only if there are extras
                  if (discount > 0 || shipping > 0 || packaging > 0)
                    _totalRow('Subtotal', subtotal, fs(9),
                        settings.currencySymbol, money,
                        decimal: settings.printAmountWithDecimal),
                  // FIX: discount now shows
                  if (discount > 0)
                    _totalRow('Discount', discount, fs(9),
                        settings.currencySymbol, money,
                        decimal: settings.printAmountWithDecimal,
                        prefix: '- '),
                  if (shipping > 0)
                    _totalRow('Shipping', shipping, fs(9),
                        settings.currencySymbol, money,
                        decimal: settings.printAmountWithDecimal),
                  if (packaging > 0)
                    _totalRow('Packaging', packaging, fs(9),
                        settings.currencySymbol, money,
                        decimal: settings.printAmountWithDecimal),
                  _totalRow('Total', total, fs(9), settings.currencySymbol,
                      money,
                      bold: true,
                      decimal: settings.printAmountWithDecimal),
                  // FIX: paid now shows
                  if (settings.printReceivedAmount && paid > 0)
                    _totalRow('Paid', paid, fs(9), settings.currencySymbol,
                        money,
                        decimal: settings.printAmountWithDecimal),
                  if (settings.printBalanceAmount)
                    _totalRow('Balance', balance, fs(9),
                        settings.currencySymbol, money,
                        decimal: settings.printAmountWithDecimal),
                  // FIX: only show prev/current bal when non-zero and meaningful
                  if (prevBal != 0 && (curBal - balance).abs() > 0.01) ...[
                    _totalRow('Previous Bal.', prevBal, fs(9),
                        settings.currencySymbol, money,
                        decimal: settings.printAmountWithDecimal),
                    _totalRow('Current Bal.', curBal, fs(9),
                        settings.currencySymbol, money,
                        bold: true,
                        decimal: settings.printAmountWithDecimal),
                  ],

                  // FIX: delivery boy name on PDF
                  if (deliveryName.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    _rule(),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Delivery by: $deliveryName',
                      style: pw.TextStyle(
                        fontSize: fs(8.6),
                        color: PdfColors.black,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],

                  if (settings.showPaymentQr && normalizedUpiId.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    _rule(),
                    pw.SizedBox(height: 8),
                    pw.Center(
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: upiQr,
                        width: 100,
                        height: 100,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Scan this QR code to pay',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          fontSize: fs(8.4), color: PdfColors.black),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'UPI ID:',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: fs(7.8),
                        color: PdfColors.black,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      normalizedUpiId,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: fs(8.3),
                        color: PdfColors.black,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Amount: ${total.toStringAsFixed(settings.printAmountWithDecimal ? 2 : 0)}',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: fs(8),
                        color: PdfColors.black,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 8),
                  _rule(),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Terms & Conditions',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: fs(9.4),
                      color: PdfColors.black,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    '----',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                        fontSize: fs(8.2), color: PdfColors.black),
                  ),
                  if (settings.showFooterMessage &&
                      settings.footerMessage.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 7),
                    _rule(),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      settings.footerMessage.trim(),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: fs(8.6),
                        color: PdfColors.black,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  static String _formatQty(double value) {
    if ((value - value.roundToDouble()).abs() < 0.001) {
      return value.toStringAsFixed(0);
    }
    if ((value * 10 - (value * 10).roundToDouble()).abs() < 0.001) {
      return value.toStringAsFixed(1);
    }
    return value.toStringAsFixed(2);
  }

  static pw.Widget _rule() => pw.Container(
        height: 1,
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.45),
          ),
        ),
      );

  static pw.Widget _metaText(
    String text,
    double fontSize, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: fontSize,
        color: PdfColors.black,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    );
  }

  static pw.Widget _headerCell(
    String text,
    double fontSize,
    pw.TextAlign align,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: fontSize,
          color: PdfColors.black,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _valueCell(
    String text,
    double fontSize, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: fontSize,
          color: PdfColors.black,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _totalRow(
    String label,
    double value,
    double fontSize,
    String sym,
    NumberFormat money, {
    bool bold = false,
    bool decimal = true,
    String prefix = '',
  }) {
    final valStr = decimal ? money.format(value) : value.toStringAsFixed(0);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              color: PdfColors.black,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            '$prefix$sym$valStr',
            style: pw.TextStyle(
              fontSize: fontSize,
              color: PdfColors.black,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}