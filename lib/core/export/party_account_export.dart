import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class PartyAccountExport {
  // ── CSV helpers ──────────────────────────────────────────────────────────
  static String _csvCell(String? v) {
    if (v == null) return '';
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static String buildPartyStatementCsv({
    required String partyName,
    required String partyType,
    required String currencySymbol,
    required double closingBalance,
    required List<Map<String, dynamic>> ledgerRows,
  }) {
    final buf = StringBuffer();
    buf.writeln('Party,${_csvCell(partyName)}');
    buf.writeln('Type,${_csvCell(partyType)}');
    buf.writeln(
        'Closing Balance,$currencySymbol${closingBalance.toStringAsFixed(2)}');
    buf.writeln();
    buf.writeln(
        'Date,Txn Type,Invoice/Bill No.,Total Amount,Received/Paid Amount,Txn Balance');
    for (final r in ledgerRows) {
      final kind   = r['kind']?.toString() ?? '';
      final date   = r['date']?.toString() ?? '';
      final ref    = r['ref']?.toString() ?? '';
      final total  = (r['total']         as num?)?.toDouble();
      final paid   = (r['paid']          as num?)?.toDouble();
      final payAmt = (r['paymentAmount'] as num?)?.toDouble();
      final due    = (r['due']           as num?)?.toDouble();
      if (kind == 'payment') {
        buf.writeln(
            '$date,Payment-in,$ref,,${payAmt?.toStringAsFixed(2) ?? ''},');
      } else {
        buf.writeln('$date,$kind,$ref,'
            '${total?.toStringAsFixed(2) ?? ''},'
            '${paid?.toStringAsFixed(2) ?? ''},'
            '${due?.toStringAsFixed(2) ?? ''}');
      }
    }
    return buf.toString();
  }

  static String buildAllPartiesCsv(List<Map<String, dynamic>> customers) {
    final buf = StringBuffer();
    buf.writeln('Name,Phone,Party Type,Balance');
    for (final m in customers) {
      buf.writeln(
        '${_csvCell(m['name']?.toString())},'
        '${_csvCell(m['phone']?.toString())},'
        '${_csvCell(m['party_type']?.toString())},'
        '${(m['balance'] as num?)?.toDouble() ?? 0}',
      );
    }
    return buf.toString();
  }

  static Future<void> shareCsv(String filename, String csv) async {
    final dir  = await getTemporaryDirectory();
    final safe = filename.replaceAll(RegExp(r'[^\w\-.]+'), '_');
    final file = File('${dir.path}/$safe');
    await file.writeAsString(csv, flush: true);
    await Share.shareXFiles([XFile(file.path)], subject: safe);
  }

  // ── MAIN PDF EXPORT ──────────────────────────────────────────────────────
  static Future<void> sharePartyStatementPdf({
    required String shopName,
    required String shopPhone,
    String shopEmail   = '',
    String shopAddress = '',
    required String partyName,
    required String partyPhone,
    required String partyType, // 'customer' | 'supplier'
    required String currencySymbol,
    double openingReceivable = 0,
    double openingPayable    = 0,
    String? fromDate,
    String? toDate,
    required List<Map<String, dynamic>> ledgerRows,
    pw.ImageProvider? shopLogoImage,
    bool showItemDetails        = false,
    bool showDescription        = false,
    bool showPaymentStatus      = false,
    bool showPaymentInformation = true,
    String? fileName,
    // ── KEY: pass actual DB balance as the definitive closing balance ──
    double? closingBalance,
  }) async {
    final pdf     = pw.Document();
    final dateFmt = DateFormat('dd/MM/yyyy');
    final now     = DateTime.now();

    final resolvedFrom = fromDate ??
        DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
    final resolvedTo =
        toDate ?? DateFormat('yyyy-MM-dd').format(now);

    String fmtDate(String raw) {
      final dt = DateTime.tryParse(raw);
      return dt == null ? raw : dateFmt.format(dt);
    }

    String money(double? v) => v == null ? '' : '$currencySymbol${_fmt(v)}';

    // ── Colours ──
    const navyBg    = PdfColor.fromInt(0xFF1A237E);
    const borderCol = PdfColor.fromInt(0xFFBDBDBD);
    const altRow    = PdfColor.fromInt(0xFFF9F9F9);
    const payRow    = PdfColor.fromInt(0xFFF1F8E9);
    const grandRow  = PdfColor.fromInt(0xFFE8EAF6);

    // ── Text styles ──
    final colHdrStyle = pw.TextStyle(
        fontSize: 7,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white);
    const cellStyle = pw.TextStyle(fontSize: 8);
    final boldSmall =
        pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold);
    const greyStyle =
        pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700);
    final boldCell =
        pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold);

    // ────────────────────────────────────────────────────────────────────────
    // RUNNING BALANCE + GRAND TOTALS — FIXED LOGIC
    //
    // grandBillTotal   = sum of invoice/purchase TOTAL amounts
    // grandPaidOnBill  = sum of amounts paid AT TIME OF BILLING
    //                    (the 'paid' field on each invoice/purchase)
    // grandPaymentIn   = sum of all SEPARATE party payments
    // grandTxnBalance  = sum of unpaid dues per bill (each bill's 'due')
    //
    // CLOSING BALANCE (source of truth) = customer.balance from DB
    //   This is what _syncCustomerBalance keeps up to date.
    //   We use it for the summary box to avoid any rounding drift.
    //
    // Running balance per row:
    //   bill row    : runBalance += due (unpaid portion of that bill)
    //   payment row : runBalance -= paymentAmount
    // ────────────────────────────────────────────────────────────────────────
    final computed = <Map<String, dynamic>>[];

    // Start from opening balance (0 unless caller passes a value)
    double runBalance =
        partyType == 'supplier' ? openingPayable : openingReceivable;

    double grandBillTotal  = 0; // total face value of all bills
    double grandPaidOnBill = 0; // paid at time of billing
    double grandPaymentIn  = 0; // separate party payments
    double grandTxnBalance = 0; // sum of unpaid dues across bills

    for (final r in ledgerRows) {
      final row  = Map<String, dynamic>.from(r);
      final kind = (r['kind']?.toString() ?? '').toLowerCase();

      if (kind == 'payment') {
        // ── Separate party payment ──
        final payAmt = (r['paymentAmount'] as num?)?.toDouble() ?? 0;
        grandPaymentIn += payAmt;
        runBalance     -= payAmt;
        // Allow negative (credit balance) — do NOT clamp to 0
        // Clamping hides overpayments and breaks the running total

        row['_runBalance']        = runBalance;
        row['_receivableBalance'] = partyType == 'customer' ? runBalance : 0.0;
        row['_payableBalance']    = partyType == 'supplier' ? runBalance : 0.0;
      } else {
        // ── Sale / Purchase bill ──
        final total = (r['total'] as num?)?.toDouble() ?? 0;
        final paid  = (r['paid']  as num?)?.toDouble() ?? 0;
        // 'due' = invoice.balance (unpaid portion stored at save time)
        final due   = (r['due'] as num?)?.toDouble() ?? (total - paid).clamp(0.0, double.infinity);

        grandBillTotal  += total;
        grandPaidOnBill += paid;
        grandTxnBalance += due;
        runBalance      += due;

        row['_txnBalance']        = due;
        row['_runBalance']        = runBalance;
        row['_receivableBalance'] = partyType == 'customer' ? runBalance : 0.0;
        row['_payableBalance']    = partyType == 'supplier' ? runBalance : 0.0;
      }
      computed.add(row);
    }

    // ── Use DB balance as definitive closing figure ──
    // This is the single source of truth — avoids any accumulated
    // rounding error from the running total above.
    final dbClosingBalance  = closingBalance ?? runBalance;
    final closingReceivable = partyType == 'customer' ? dbClosingBalance : 0.0;
    final closingPayable    = partyType == 'supplier' ? dbClosingBalance : 0.0;

    // ── FIX: Total Paid Amount in summary ──
    // = paid-at-billing + separate party payments
    // Previously only grandPaidOnBill was shown, causing mismatch
    final grandTotalPaid = grandPaidOnBill + grandPaymentIn;

    // ── Column widths ──
    final colWidths = {
      0: const pw.FixedColumnWidth(52),
      1: const pw.FixedColumnWidth(52),
      2: const pw.FixedColumnWidth(62),
      3: const pw.FixedColumnWidth(38),
      4: const pw.FixedColumnWidth(46),
      5: const pw.FixedColumnWidth(46),
      6: const pw.FixedColumnWidth(46),
      7: const pw.FixedColumnWidth(52),
      8: const pw.FixedColumnWidth(46),
    };

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),

      header: (ctx) => pw.Column(children: [
        pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (shopLogoImage != null)
                pw.Container(
                    width: 72,
                    height: 56,
                    child: pw.Image(shopLogoImage,
                        fit: pw.BoxFit.contain))
              else
                pw.SizedBox(width: 4),
              pw.Spacer(),
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                        shopName.isEmpty ? 'Business' : shopName,
                        style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold)),
                    if (shopAddress.isNotEmpty)
                      pw.Text(shopAddress, style: greyStyle),
                    pw.Text(
                      [
                        if (shopPhone.isNotEmpty)
                          'Phone no.: $shopPhone',
                        if (shopEmail.isNotEmpty)
                          'Email: $shopEmail',
                      ].join('  '),
                      style: greyStyle,
                    ),
                  ]),
            ]),
        pw.SizedBox(height: 5),
        pw.Divider(thickness: 0.6, color: PdfColors.grey400),
      ]),

      build: (ctx) => [
        pw.Center(
            child: pw.Text('Party Statement',
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    decoration: pw.TextDecoration.underline))),
        pw.SizedBox(height: 10),

        pw.Text('Party name: $partyName',
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 3),
        pw.Text('Contact no.: $partyPhone', style: greyStyle),
        pw.SizedBox(height: 8),

        pw.Text(
            'Duration: From ${fmtDate(resolvedFrom)} to ${fmtDate(resolvedTo)}',
            style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),

        pw.Table(
          border: pw.TableBorder.all(color: borderCol, width: 0.4),
          columnWidths: colWidths,
          children: [
            // ── Header ──
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: navyBg),
              children: [
                _th('Date',                colHdrStyle),
                _th('Txn Type',            colHdrStyle),
                _th('Invoice/ Bill\nNo.',  colHdrStyle),
                _th('Status',              colHdrStyle),
                _th('Total\nAmount',       colHdrStyle, right: true),
                _th('Received/\nPaid Amount', colHdrStyle, right: true),
                _th('Txn\nBalance',        colHdrStyle, right: true),
                _th('Receivable\nBalance', colHdrStyle, right: true),
                _th('Payable\nBalance',    colHdrStyle, right: true),
              ],
            ),

            // ── Beginning Balance row ──
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.white),
              children: [
                _td(fmtDate(resolvedFrom), cellStyle),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Beginning\nBalance',
                        style: boldSmall)),
                _td('', cellStyle),
                _td('', cellStyle),
                _td('', cellStyle),
                _td('', cellStyle),
                _td('', cellStyle),
                _td(
                    openingReceivable > 0
                        ? money(openingReceivable)
                        : '',
                    cellStyle,
                    right: true),
                _td(
                    openingPayable > 0
                        ? money(openingPayable)
                        : '',
                    cellStyle,
                    right: true),
              ],
            ),

            // ── Data rows ──
            ...computed.asMap().entries.map((entry) {
              final idx  = entry.key;
              final r    = entry.value;
              final kind = (r['kind']?.toString() ?? '').toLowerCase();
              final isPayment = kind == 'payment';

              final total  = (r['total']            as num?)?.toDouble();
              final paid   = (r['paid']             as num?)?.toDouble();
              final payAmt = (r['paymentAmount']    as num?)?.toDouble();
              final txnBal = (r['_txnBalance']      as num?)?.toDouble();
              final recBal = (r['_receivableBalance'] as num?)?.toDouble();
              final payBal = (r['_payableBalance']  as num?)?.toDouble();
              final status = r['status']?.toString() ?? '';
              final payMode =
                  r['paymentMode']?.toString() ??
                  r['paymentMethod']?.toString() ?? '';

              final rowBg = isPayment
                  ? payRow
                  : idx.isOdd
                      ? altRow
                      : PdfColors.white;
              final displayType =
                  isPayment ? 'Payment-in' : _capitalize(kind);

              return pw.TableRow(
                decoration: pw.BoxDecoration(color: rowBg),
                children: [
                  _td(fmtDate(r['date']?.toString() ?? ''),
                      cellStyle),
                  _td(displayType, cellStyle),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 4, vertical: 3),
                    child: pw.Column(
                        crossAxisAlignment:
                            pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(r['ref']?.toString() ?? '',
                              style: cellStyle),
                          if (isPayment &&
                              showPaymentInformation &&
                              payMode.isNotEmpty)
                            pw.Text('Payment Type: $payMode',
                                style: const pw.TextStyle(
                                    fontSize: 7,
                                    color: PdfColors.grey700)),
                          if (showDescription &&
                              (r['notes']
                                      ?.toString()
                                      .isNotEmpty ??
                                  false))
                            pw.Text(
                                'Description: ${r['notes']}',
                                style: const pw.TextStyle(
                                    fontSize: 7,
                                    color: PdfColors.grey700)),
                        ]),
                  ),
                  _td(showPaymentStatus ? status : '', cellStyle),
                  // ── FIX: Payment rows show NOTHING in Total Amount ──
                  _td(isPayment ? '' : money(total), cellStyle,
                      right: true),
                  // ── FIX: Bill rows show paid-at-billing;
                  //         Payment rows show payment amount ──
                  _td(isPayment ? money(payAmt) : money(paid),
                      cellStyle, right: true),
                  // ── Txn Balance: only for bills, blank for payments ──
                  _td(isPayment ? '' : money(txnBal), cellStyle,
                      right: true),
                  _td(
                      partyType == 'customer' && recBal != null
                          ? money(recBal)
                          : '',
                      cellStyle,
                      right: true),
                  _td(
                      partyType == 'supplier' &&
                              payBal != null &&
                              payBal > 0
                          ? money(payBal)
                          : '',
                      cellStyle,
                      right: true),
                ],
              );
            }),

            // ── Grand Total row ──
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: grandRow),
              children: [
                _td('', boldCell),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Total', style: boldCell)),
                _td('', boldCell),
                _td('', boldCell),
                // Total Amount = sum of bill totals (no payment rows)
                _td(money(grandBillTotal), boldCell, right: true),
                // Received/Paid = paid-at-billing + party payments
                _td(money(grandTotalPaid), boldCell, right: true),
                // Txn Balance = total unpaid dues across all bills
                _td(money(grandTxnBalance), boldCell, right: true),
                _td(
                    partyType == 'customer' &&
                            closingReceivable > 0
                        ? money(closingReceivable)
                        : '',
                    boldCell,
                    right: true),
                _td(
                    partyType == 'supplier' && closingPayable > 0
                        ? money(closingPayable)
                        : '',
                    boldCell,
                    right: true),
              ],
            ),
          ],
        ),

        if (showItemDetails &&
            computed.any(
                (r) => ((r['items'] as List?) ?? const []).isNotEmpty))
          ..._buildItemDetailsSections(
            computed: computed,
            fmtDate: fmtDate,
            money: money,
            borderCol: borderCol,
            headerColor: PdfColors.grey300,
          ),

        pw.SizedBox(height: 16),

        // ── Summary box ──
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
              border: pw.Border.all(color: borderCol, width: 0.5),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(4))),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Total Bill Amount = sum of all bill totals
                _summaryRow('Total Bill Amount',
                    money(grandBillTotal), greyStyle, boldCell),
                // Total Paid Amount = paid at billing only
                _summaryRow('Total Paid Amount',
                    money(grandPaidOnBill), greyStyle, boldCell),
                // Total Payment In = separate party payments
                _summaryRow('Total Payment In',
                    money(grandPaymentIn), greyStyle, boldCell),
                pw.Divider(
                    thickness: 0.5, color: PdfColors.grey400),
                // Closing balance from DB (source of truth)
                if (closingReceivable > 0)
                  _summaryRow(
                      'Total Receivable Balance',
                      money(closingReceivable),
                      greyStyle,
                      pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(
                              0xFFE65100))),
                if (closingPayable > 0)
                  _summaryRow(
                      'Total Payable Balance',
                      money(closingPayable),
                      greyStyle,
                      pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(
                              0xFF1A237E))),
              ]),
        ),
      ],
    ));

    final dir = await getTemporaryDirectory();
    final safeName = (fileName?.trim().isNotEmpty == true
            ? fileName!.trim()
            : partyName)
        .replaceAll(RegExp(r'[^\w\-.]+'), '_');
    final file = File('${dir.path}/$safeName.pdf');
    await file.writeAsBytes(await pdf.save(), flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Party Statement - $partyName',
    );
  }

  // ── All Parties PDF ──────────────────────────────────────────────────────
  static Future<void> shareAllPartiesPdf({
    required String shopName,
    required String shopPhone,
    required String currencySymbol,
    required List<Map<String, dynamic>> customers,
  }) async {
    final pdf = pw.Document();
    const navyBg = PdfColor.fromInt(0xFF1A237E);

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (context) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
              color: navyBg,
              borderRadius: pw.BorderRadius.circular(10)),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(shopName.isEmpty ? 'Business' : shopName,
                    style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
                if (shopPhone.isNotEmpty)
                  pw.Text('Phone: $shopPhone',
                      style: const pw.TextStyle(
                          color: PdfColors.white, fontSize: 10)),
                pw.SizedBox(height: 6),
                pw.Text('All Parties Report',
                    style: const pw.TextStyle(
                        color: PdfColors.white, fontSize: 11)),
              ]),
        ),
        pw.SizedBox(height: 20),
        pw.Table(
          border: pw.TableBorder.all(
              color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2.5),
            1: pw.FlexColumnWidth(1.8),
            2: pw.FlexColumnWidth(1.5),
            3: pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: navyBg),
              children: [
                _th(
                    'Name',
                    pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
                _th(
                    'Phone',
                    pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
                _th(
                    'Type',
                    pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
                _th(
                    'Balance',
                    pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white),
                    right: true),
              ],
            ),
            ...customers.map((m) {
              final balance =
                  (m['balance'] as num?)?.toDouble() ?? 0;
              final isSupplier =
                  m['party_type']?.toString() == 'supplier';
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: isSupplier
                        ? PdfColors.indigo50
                        : PdfColors.white),
                children: [
                  _td(m['name']?.toString() ?? '',
                      const pw.TextStyle(fontSize: 9)),
                  _td(m['phone']?.toString() ?? '-',
                      const pw.TextStyle(fontSize: 9)),
                  _td(isSupplier ? 'Supplier' : 'Customer',
                      const pw.TextStyle(fontSize: 9)),
                  _td(
                      '$currencySymbol${balance.toStringAsFixed(2)}',
                      const pw.TextStyle(fontSize: 9),
                      right: true),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text('Total Parties: ${customers.length}',
            style: const pw.TextStyle(fontSize: 10)),
      ],
    ));

    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/all_parties.pdf');
    await file.writeAsBytes(await pdf.save(), flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'All Parties Report',
    );
  }

  // ── Widget helpers ───────────────────────────────────────────────────────
  static pw.Widget _th(String text, pw.TextStyle style,
          {bool right = false}) =>
      pw.Padding(
          padding: const pw.EdgeInsets.symmetric(
              horizontal: 3, vertical: 5),
          child: pw.Text(text,
              style: style,
              textAlign: right
                  ? pw.TextAlign.right
                  : pw.TextAlign.center));

  static pw.Widget _td(String text, pw.TextStyle style,
          {bool right = false}) =>
      pw.Padding(
          padding: const pw.EdgeInsets.symmetric(
              horizontal: 3, vertical: 4),
          child: pw.Text(text,
              style: style,
              textAlign: right
                  ? pw.TextAlign.right
                  : pw.TextAlign.left));

  static pw.Widget _summaryRow(String label, String value,
          pw.TextStyle labelStyle, pw.TextStyle valueStyle) =>
      pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(children: [
            pw.Text(label, style: labelStyle),
            pw.Spacer(),
            pw.Text(value, style: valueStyle),
          ]));

  static List<pw.Widget> _buildItemDetailsSections({
    required List<Map<String, dynamic>> computed,
    required String Function(String raw) fmtDate,
    required String Function(double? value) money,
    required PdfColor borderCol,
    required PdfColor headerColor,
  }) {
    final sections = <pw.Widget>[
      pw.SizedBox(height: 12),
      pw.Text('Item Details',
          style: pw.TextStyle(
              fontSize: 10, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 5),
    ];

    for (final r in computed) {
      final kind = (r['kind']?.toString() ?? '').toLowerCase();
      if (kind == 'payment') continue;
      final items = ((r['items'] as List?) ?? const [])
          .map((raw) =>
              Map<String, dynamic>.from(raw as Map))
          .toList();
      if (items.isEmpty) continue;

      final totalQty = items.fold<double>(
          0,
          (s, i) =>
              s +
              ((i['quantity'] as num?)?.toDouble() ?? 0));
      final totalAmount = items.fold<double>(
          0,
          (s, i) =>
              s + ((i['amount'] as num?)?.toDouble() ?? 0));

      sections.add(pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        decoration: pw.BoxDecoration(
            border:
                pw.Border.all(color: borderCol, width: 0.4)),
        child: pw.Column(
            crossAxisAlignment:
                pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 5, vertical: 4),
                  color: PdfColors.grey100,
                  child: pw.Text(
                    '${fmtDate(r['date']?.toString() ?? '')}  ${_capitalize(kind)}  ${r['ref'] ?? ''}',
                    style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold),
                  )),
              pw.Table(
                border: pw.TableBorder.all(
                    color: borderCol, width: 0.35),
                columnWidths: const {
                  0: pw.FixedColumnWidth(24),
                  1: pw.FlexColumnWidth(2.4),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FlexColumnWidth(0.8),
                  4: pw.FlexColumnWidth(1),
                  5: pw.FlexColumnWidth(1.2),
                },
                children: [
                  pw.TableRow(
                    decoration:
                        pw.BoxDecoration(color: headerColor),
                    children: [
                      _th('#', const pw.TextStyle(fontSize: 7)),
                      _th('Item name',
                          const pw.TextStyle(fontSize: 7)),
                      _th('Quantity',
                          const pw.TextStyle(fontSize: 7),
                          right: true),
                      _th('Unit',
                          const pw.TextStyle(fontSize: 7)),
                      _th('Price/unit',
                          const pw.TextStyle(fontSize: 7),
                          right: true),
                      _th('Amount',
                          const pw.TextStyle(fontSize: 7),
                          right: true),
                    ],
                  ),
                  ...items.asMap().entries.map((entry) {
                    final idx    = entry.key + 1;
                    final item   = entry.value;
                    final qty    = (item['quantity'] as num?)?.toDouble() ?? 0.0;
                    final price  = (item['price']    as num?)?.toDouble() ?? 0.0;
                    final amount = (item['amount']   as num?)?.toDouble() ?? 0.0;
                    return pw.TableRow(children: [
                      _td('$idx',
                          const pw.TextStyle(fontSize: 7)),
                      _td(
                          item['item_name']?.toString() ??
                              '',
                          const pw.TextStyle(fontSize: 7)),
                      _td(_qty(qty),
                          const pw.TextStyle(fontSize: 7),
                          right: true),
                      _td(
                          item['unit']?.toString() ?? '',
                          const pw.TextStyle(fontSize: 7)),
                      _td(money(price),
                          const pw.TextStyle(fontSize: 7),
                          right: true),
                      _td(money(amount),
                          const pw.TextStyle(fontSize: 7),
                          right: true),
                    ]);
                  }),
                  pw.TableRow(children: [
                    _td('', const pw.TextStyle(fontSize: 7)),
                    _td(
                        'Total',
                        pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold)),
                    _td(
                        _qty(totalQty),
                        pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold),
                        right: true),
                    _td('', const pw.TextStyle(fontSize: 7)),
                    _td('', const pw.TextStyle(fontSize: 7)),
                    _td(
                        money(totalAmount),
                        pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold),
                        right: true),
                  ]),
                ],
              ),
            ]),
      ));
    }
    return sections;
  }

  static String _qty(double v) {
    if ((v - v.roundToDouble()).abs() < 0.001) {
      return v.toStringAsFixed(0);
    }
    return v.toStringAsFixed(2);
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  static String _fmt(double v) =>
      NumberFormat('#,##,##0.00', 'en_IN').format(v);
}