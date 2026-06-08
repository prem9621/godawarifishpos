import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../core/constants/app_constants.dart';
import '../providers/settings_provider.dart';

class PrinterService {
  PrinterService._();
  static final PrinterService instance = PrinterService._();

  // ─────────────── CONNECTION ───────────────

  Future<bool> isConnected() async =>
      await PrintBluetoothThermal.connectionStatus;

  Future<List<BluetoothInfo>> getBondedDevices() async =>
      await PrintBluetoothThermal.pairedBluetooths;

  /// Connect by MAC address. Pass [BluetoothInfo.macAdress] from [getBondedDevices].
  Future<bool> connect(String macAddress) async {
    if (await isConnected()) return true;
    return await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
  }

  Future<void> disconnect() async => PrintBluetoothThermal.disconnect;

  // ─────────────── HELPERS ───────────────

  String formatQty(double qty) {
    if (qty == qty.roundToDouble()) return qty.toInt().toString();
    return qty.toStringAsFixed(1);
  }

  String _rs(double v, bool decimal) =>
      'Rs.${v.toStringAsFixed(decimal ? 2 : 0)}';

  Future<void> _write(List<int> chunk) async {
    if (chunk.isEmpty) return;
    await PrintBluetoothThermal.writeBytes(chunk);
  }

  // ─────────────── PRINT BILL ───────────────

  Future<void> printInvoice({
    required SettingsProvider settings,
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> items,
    String? upiId,
  }) async {
    final connected = await isConnected();
    if (!connected) throw Exception('Printer not connected');

    final profile = await CapabilityProfile.load();
    final paperSize =
        settings.thermalPaperWidthMm == 58 ? PaperSize.mm58 : PaperSize.mm80;
    final gen = Generator(paperSize, profile);
    final decimal = settings.printAmountWithDecimal;

    // Alias for brevity
    final w = _write;

    final shopName =
        settings.shopName.isEmpty ? AppConstants.shopName : settings.shopName;

    // ══════════════════════════════════
    //  LOGO
    // ══════════════════════════════════
    if (settings.printLogo) {
      try {
        final ByteData data = await rootBundle.load('assets/logo.png');
        final Uint8List logoBytes = data.buffer.asUint8List();
        final image = img.decodeImage(logoBytes);
        if (image != null) {
          final resized = img.copyResize(
            image,
            width: settings.thermalPaperWidthMm == 58 ? 120 : 180,
          );
          await w(gen.imageRaster(resized, align: PosAlign.center));
          await w(gen.feed(1));
        }
      } catch (_) {}
    }

    // ══════════════════════════════════
    //  SHOP NAME — big bold centered
    // ══════════════════════════════════
    if (settings.printShopName) {
      await w(gen.text(
        shopName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size1,
        ),
      ));
      await w(gen.feed(1));
    }

    // Tagline bold centered
    await w(gen.text(
      AppConstants.shopTagline,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));

    // Sub-tagline
    await w(gen.text(
      '* HOME DELIVERY  * HOTEL SUPPLIERS  * RETAIL OUTLETS',
      styles: const PosStyles(align: PosAlign.center),
    ));

    await w(gen.feed(1));

    if (settings.printShopAddress && settings.shopAddress.isNotEmpty) {
      await w(gen.text(
        settings.shopAddress,
        styles: const PosStyles(align: PosAlign.center),
      ));
    }
    if (settings.printShopPhone && settings.shopPhone.isNotEmpty) {
      await w(gen.text(
        'Ph: ${settings.shopPhone}',
        styles: const PosStyles(align: PosAlign.center),
      ));
    }
    if (settings.printShopEmail && settings.shopEmail.isNotEmpty) {
      await w(gen.text(
        'Email: ${settings.shopEmail}',
        styles: const PosStyles(align: PosAlign.center),
      ));
    }

    await w(gen.hr(ch: '='));

    // ══════════════════════════════════
    //  BILL INVOICE — bold centered
    // ══════════════════════════════════
    await w(gen.text(
      'B I L L  I N V O I C E',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));

    await w(gen.hr(ch: '='));

    // ══════════════════════════════════
    //  INVOICE META
    // ══════════════════════════════════
    final createdAt =
        DateTime.tryParse(invoice['created_at']?.toString() ?? '') ??
            DateTime.now();
    final invoiceNo = invoice['invoice_no']?.toString() ?? '0000';
    final dateStr = DateFormat('dd/MM/yyyy').format(createdAt);
    final timeStr = DateFormat('hh:mm a').format(createdAt);

    await w(gen.text(
      'Invoice No: $invoiceNo  Date: $dateStr',
      styles: const PosStyles(bold: true),
    ));
    await w(gen.text('Time: $timeStr'));

    await w(gen.hr(ch: '-'));

    // ══════════════════════════════════
    //  BILL TO
    // ══════════════════════════════════
    final customerName = invoice['customer_name']?.toString().trim() ?? '';
    final customerPhone = invoice['customer_phone']?.toString().trim() ?? '';

    await w(gen.text('Bill To:'));
    await w(gen.text(
      customerName.isEmpty ? 'WALK-IN CUSTOMER' : customerName.toUpperCase(),
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    if (customerPhone.isNotEmpty) {
      await w(gen.text(
        'Ph: $customerPhone',
        styles: const PosStyles(align: PosAlign.center),
      ));
    }

    await w(gen.hr(ch: '-'));

    // ══════════════════════════════════
    //  ITEM TABLE HEADER
    // ══════════════════════════════════
    await w(gen.row([
      PosColumn(width: 1, text: '#', styles: const PosStyles(bold: true)),
      PosColumn(
          width: 5, text: 'Item Name', styles: const PosStyles(bold: true)),
      PosColumn(
          width: 3,
          text: 'Price',
          styles: const PosStyles(bold: true, align: PosAlign.right)),
      PosColumn(
          width: 3,
          text: 'Amount',
          styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]));

    await w(gen.hr(ch: '-'));

    // ══════════════════════════════════
    //  ITEMS
    // ══════════════════════════════════
    double subTotal = 0;
    double totalQtyKg = 0;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
      final price = (item['price'] as num?)?.toDouble() ?? 0;
      final amount = (item['amount'] as num?)?.toDouble() ?? 0;
      final unit = item['unit']?.toString().trim() ?? 'Kg';
      final name = item['item_name']?.toString() ?? 'Item';

      subTotal += amount;
      totalQtyKg += qty;

      await w(gen.row([
        PosColumn(
            width: 1, text: '${i + 1}', styles: const PosStyles(bold: true)),
        PosColumn(width: 5, text: name, styles: const PosStyles(bold: true)),
        PosColumn(
          width: 3,
          text: price.toStringAsFixed(decimal ? 2 : 0),
          styles: const PosStyles(align: PosAlign.right),
        ),
        PosColumn(
          width: 3,
          text: amount.toStringAsFixed(decimal ? 2 : 0),
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]));

      // Qty row below name — e.g. "  9 Kg"
      if (settings.printUnit) {
        await w(gen.row([
          PosColumn(width: 1, text: ''),
          PosColumn(width: 11, text: '  ${formatQty(qty)} $unit'),
        ]));
      }
    }

    await w(gen.hr(ch: '-'));

    // ══════════════════════════════════
    //  QTY / ITEMS / SUBTOTAL ROW
    // ══════════════════════════════════
    await w(gen.row([
      PosColumn(
        width: 4,
        text: 'Qty: ${formatQty(totalQtyKg)}',
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        width: 4,
        text: 'Items: ${items.length}',
        styles: const PosStyles(bold: true, align: PosAlign.center),
      ),
      PosColumn(
        width: 4,
        text: subTotal.toStringAsFixed(decimal ? 2 : 0),
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
    ]));

    await w(gen.hr(ch: '='));

    // ══════════════════════════════════════════════════════════
    //  TOTALS SECTION
    // ══════════════════════════════════════════════════════════
    final shipping = (invoice['shipping'] as num?)?.toDouble() ?? 0;
    final packaging = (invoice['packaging'] as num?)?.toDouble() ?? 0;
    final grandTotal = (invoice['total'] as num?)?.toDouble() ?? subTotal;
    final paid = (invoice['paid'] as num?)?.toDouble() ?? 0;
    final balance =
        (invoice['balance'] as num?)?.toDouble() ?? (grandTotal - paid);
    final prevBal = (invoice['previous_balance'] as num?)?.toDouble() ?? 0;
    final curBal = (invoice['current_balance'] as num?)?.toDouble() ?? balance;

    Future<void> totalRow(String label, double value,
        {bool bold = false}) async {
      await w(gen.row([
        PosColumn(width: 2, text: ''),
        PosColumn(width: 6, text: label, styles: PosStyles(bold: bold)),
        PosColumn(width: 1, text: ':'),
        PosColumn(
          width: 3,
          text: _rs(value, decimal),
          styles: PosStyles(bold: bold, align: PosAlign.right),
        ),
      ]));
    }

    await totalRow('Subtotal', subTotal);
    if (shipping > 0) await totalRow('Shipping', shipping);
    if (packaging > 0) await totalRow('Packaging', packaging);

    await w(gen.hr(ch: '-'));

    await totalRow('Total', grandTotal, bold: true);
    await totalRow('Paid', paid);
    await totalRow('Balance', balance, bold: true);
    if (prevBal != 0) await totalRow('Prev. Bal.', prevBal);
    await totalRow('Current Bal', curBal, bold: true);

    await w(gen.hr(ch: '='));

    // ══════════════════════════════════
    //  FOOTER
    // ══════════════════════════════════
    await w(gen.feed(1));

    if (settings.showFooterMessage &&
        settings.footerMessage.trim().isNotEmpty) {
      await w(gen.text(
        settings.footerMessage.trim(),
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ));
    } else {
      await w(gen.text(
        'Thank You For Your Business!',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ));
    }

    // ══════════════════════════════════
    //  RECEIVED SIGN / DELIVERY BY
    // ══════════════════════════════════
    await w(gen.feed(1));
    await w(gen.text('Received Sign: _______________'));
    await w(gen.feed(1));
    await w(gen.text('Delivery by:   _______________'));

    await w(gen.feed(settings.extraLinesAtPrintEnd + 2));

    if (settings.autoCutPaper) {
      await w(gen.cut());
    }
  }
}
