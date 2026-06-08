import 'dart:io';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/settings_provider.dart';

class ThermalInvoicePrinter {
  ThermalInvoicePrinter._();

  // ── Permissions ───────────────────────────────────────────────────────────
  static Future<String?> _ensurePermissions() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    final c = await Permission.bluetoothConnect.request();
    if (!c.isGranted) return 'Bluetooth connect permission required.';
    final sc = await Permission.bluetoothScan.request();
    if (!sc.isGranted) return 'Bluetooth scan permission required.';
    return null;
  }

  // ── txt() helper — forces PC437 codepage, fixes blank text on Chinese printers
  static List<int> _txt(
    Generator gen,
    String text, {
    PosStyles styles = const PosStyles(),
  }) {
    return gen.text(text, styles: styles, containsChinese: false);
  }

  // ── Init bytes — MUST be sent before any text. Resets the printer to a
  //    known state and forces codepage PC437 + cancels Kanji mode so English
  //    text prints correctly on Chinese-market 76mm/80mm import printers.
  static List<int> _initBytes() => <int>[
        0x1B, 0x40,         // ESC @   → Initialise / hard reset printer
        0x1B, 0x74, 0x00,   // ESC t 0 → Select codepage PC437 (USA)
        0x1C, 0x2E,         // FS  .   → Cancel Chinese / Kanji mode (CRITICAL)
        0x1B, 0x52, 0x00,   // ESC R 0 → International char set: USA
        0x1B, 0x61, 0x00,   // ESC a 0 → Left align
        0x1B, 0x32,         // ESC 2   → Default line spacing
      ];

  // ── Connect / send / disconnect ───────────────────────────────────────────
  static Future<String?> _withPrinter(
    SettingsProvider settings,
    Future<List<int>> Function(Generator gen) buildReceipt,
  ) async {
    final addr = settings.bluetoothPrinter.trim();
    if (addr.isEmpty) return 'Choose a Bluetooth printer in Settings first.';

    if (Platform.isAndroid) {
      final perm = await _ensurePermissions();
      if (perm != null) return perm;
    }

    final isOn = await PrintBluetoothThermal.bluetoothEnabled;
    if (!isOn) return 'Bluetooth is turned off. Please enable it.';

    final bonded = await PrintBluetoothThermal.pairedBluetooths;
    final dev = bonded
        .cast<BluetoothInfo?>()
        .firstWhere((d) => d?.macAdress == addr, orElse: () => null);
    if (dev == null) return 'Saved printer not found. Re-select in Settings.';

    // ✅ Load profile & build ALL bytes BEFORE connecting.
    // Cheap printers have a short RFCOMM idle timeout — if we do async
    // work after connect(), the socket closes before we write anything.
    final profile = await CapabilityProfile.load();

    // Pick paper size based on user setting.
    // 58mm  → PaperSize.mm58
    // 76mm  → PaperSize.mm80 (3-inch import printers share the 80mm profile)
    // 80mm  → PaperSize.mm80
    final paperSize = settings.thermalPaperWidthMm == 58
        ? PaperSize.mm58
        : PaperSize.mm80;
    final gen = Generator(paperSize, profile);
    final bytes = await buildReceipt(gen);
    debugPrint('🖨️ Bytes to send: ${bytes.length} '
        '(paper=${settings.thermalPaperWidthMm}mm)');
    if (bytes.isEmpty) return 'Nothing to print.';

    // Connect — bytes are already built, write starts right after settle delay
    bool connected = false;
    try {
      connected = await PrintBluetoothThermal.connect(
          macPrinterAddress: dev.macAdress);
    } catch (e) {
      return 'Could not connect to printer: $e';
    }
    if (!connected) return 'Could not connect to printer.';

    try {
      // Give RFCOMM channel time to stabilise before first write
      await Future.delayed(const Duration(milliseconds: 800));

      await PrintBluetoothThermal.writeBytes(bytes);

      // Wait for printer to physically finish before we disconnect
      await Future.delayed(const Duration(milliseconds: 1500));
    } catch (e) {
      return 'Print failed: $e';
    } finally {
      try {
        await PrintBluetoothThermal.disconnect;
      } catch (_) {}
    }
    return null;
  }

  // ── Format helpers ────────────────────────────────────────────────────────
  static String _formatQty(double v) {
    if ((v - v.roundToDouble()).abs() < 0.001) return v.toStringAsFixed(0);
    if ((v * 10 - (v * 10).roundToDouble()).abs() < 0.001) {
      return v.toStringAsFixed(1);
    }
    return v.toStringAsFixed(2);
  }

  static String _clip(String str, int max) =>
      str.length <= max ? str : '${str.substring(0, max - 2)}..';

  // ── MAIN: Print invoice ───────────────────────────────────────────────────
  static Future<String?> printInvoice({
    required SettingsProvider settings,
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> items,
  }) async {
    debugPrint('🖨️ printInvoice: ${items.length} items, '
        'invoice=${invoice['invoice_no']}');

    if (items.isEmpty) {
      return 'No items found on this bill. Cannot print.';
    }

    return _withPrinter(settings, (gen) async {
      final dec = settings.printAmountWithDecimal ? 2 : 0;
      final sym = settings.currencySymbol;
      String amt(num? v) => '$sym${(v ?? 0).toStringAsFixed(dec)}';
      String val(num? v) => (v ?? 0).toStringAsFixed(dec);

      // Shorthand that always passes containsChinese: false
      List<int> txt(String text, {PosStyles styles = const PosStyles()}) =>
          _txt(gen, text, styles: styles);

      final created =
          DateTime.tryParse(invoice['created_at']?.toString() ?? '') ??
              DateTime.now();
      final dateStr = DateFormat('dd/MM/yy').format(created);
      final timeStr = DateFormat('hh:mm a').format(created);
      final invoiceNo = invoice['invoice_no']?.toString().trim() ?? '';
      final customerName =
          invoice['customer_name']?.toString().trim().isNotEmpty == true
              ? invoice['customer_name'].toString().trim()
              : 'Walk-in Customer';
      final customerPhone =
          invoice['customer_phone']?.toString().trim() ?? '';
      final notes = invoice['notes']?.toString().trim() ?? '';
      final deliveryMatch =
          RegExp(r'Delivery:\s*([^|]+)').firstMatch(notes);
      final deliveryName = deliveryMatch?.group(1)?.trim() ?? '';

      final subtotal = (invoice['subtotal'] as num?)?.toDouble() ?? 0;
      final discount = (invoice['discount'] as num?)?.toDouble() ?? 0;
      final shipping = (invoice['shipping'] as num?)?.toDouble() ?? 0;
      final packaging = (invoice['packaging'] as num?)?.toDouble() ?? 0;
      final paid = (invoice['paid'] as num?)?.toDouble() ?? 0;
      final total = (invoice['total'] as num?)?.toDouble() ?? 0;
      final balance = (invoice['balance'] as num?)?.toDouble() ?? 0;
      final prevBal = (invoice['previous_balance'] as num?)?.toDouble() ?? 0;
      final curBal =
          (invoice['current_balance'] as num?)?.toDouble() ?? balance;

      final copies = settings.numberOfCopies.clamp(1, 3);

      final List<int> allBytes = [];

      for (int copy = 0; copy < copies; copy++) {
        if (copy > 0) {
          allBytes.addAll(gen.feed(3));
        }

        // ── INIT: hard reset + PC437 + cancel Kanji + left align ──────
        // MUST be first bytes of every copy. Fixes blank print on
        // Chinese-market 76mm/80mm printers that boot into GBK mode.
        allBytes.addAll(_initBytes());

        // Cash drawer pulse (after reset so it doesn't interfere)
        if (settings.openCashDrawer) {
          allBytes.addAll([0x1b, 0x70, 0x00, 0x19, 0xfa]);
        }

        // ── SHOP NAME ─────────────────────────────────────────────────
        if (settings.printShopName) {
          final shopName = settings.shopName.isEmpty
              ? AppConstants.shopName.toUpperCase()
              : settings.shopName.toUpperCase();

          allBytes.addAll(txt(
            shopName,
            styles: const PosStyles(
              align: PosAlign.center,
              bold: true,
              height: PosTextSize.size2,
              width: PosTextSize.size1,
            ),
          ));
        }

        if (settings.printShopAddress && settings.shopAddress.isNotEmpty) {
          allBytes.addAll(txt(
            settings.shopAddress.trim(),
            styles: const PosStyles(align: PosAlign.center),
          ));
        }
        if (settings.printShopPhone && settings.shopPhone.isNotEmpty) {
          allBytes.addAll(txt(
            'Ph: ${settings.shopPhone.trim()}',
            styles: const PosStyles(align: PosAlign.center),
          ));
        }
        if (settings.printShopEmail && settings.shopEmail.isNotEmpty) {
          allBytes.addAll(txt(
            settings.shopEmail.trim(),
            styles: const PosStyles(align: PosAlign.center),
          ));
        }
        if (settings.printGstin && settings.gstNo.isNotEmpty) {
          allBytes.addAll(txt(
            'GSTIN: ${settings.gstNo.trim()}',
            styles: const PosStyles(align: PosAlign.center),
          ));
        }

        allBytes.addAll(gen.hr(ch: '-'));

        // ── INVOICE TITLE ─────────────────────────────────────────────
        allBytes.addAll(txt(
          settings.printBillOfSupply ? 'BILL OF SUPPLY' : 'TAX INVOICE',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ));

        allBytes.addAll(gen.hr(ch: '-'));

        // ── BILL META ─────────────────────────────────────────────────
        allBytes.addAll(txt(
          'Bill: $invoiceNo',
          styles: const PosStyles(bold: true),
        ));
        allBytes.addAll(txt('Date: $dateStr   Time: $timeStr'));

        allBytes.addAll(gen.hr(ch: '-'));

        // ── CUSTOMER ──────────────────────────────────────────────────
        allBytes.addAll(txt(
          _clip(customerName.toUpperCase(), 48),
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ));
        if (customerPhone.isNotEmpty) {
          allBytes.addAll(txt(
            'Ph: $customerPhone',
            styles: const PosStyles(align: PosAlign.center),
          ));
        }

        allBytes.addAll(gen.hr(ch: '-'));

        // ── ITEM TABLE HEADER ─────────────────────────────────────────
        // 76mm and 80mm both use the wide layout.
        final is80mm = settings.thermalPaperWidthMm >= 76;

        if (is80mm) {
          allBytes.addAll(gen.row([
            if (settings.printSNo)
              PosColumn(
                  width: 1,
                  text: '#',
                  styles: const PosStyles(bold: true)),
            PosColumn(
                width: settings.printSNo ? 5 : 6,
                text: 'Item',
                styles: const PosStyles(bold: true)),
            PosColumn(
                width: 2,
                text: 'Qty',
                styles: const PosStyles(bold: true, align: PosAlign.right)),
            PosColumn(
                width: 2,
                text: 'Rate',
                styles: const PosStyles(bold: true, align: PosAlign.right)),
            PosColumn(
                width: 2,
                text: 'Amt',
                styles: const PosStyles(bold: true, align: PosAlign.right)),
          ]));
        } else {
          allBytes.addAll(txt(
            settings.printSNo
                ? '# Item       Qty Rate  Amt'
                : 'Item        Qty Rate  Amt',
            styles: const PosStyles(bold: true),
          ));
        }

        allBytes.addAll(gen.hr(ch: '-'));

        // ── ITEMS ─────────────────────────────────────────────────────
        double totalQty = 0;
        for (int i = 0; i < items.length; i++) {
          final it = items[i];
          final q = (it['quantity'] as num?)?.toDouble() ?? 0;
          final p = (it['price'] as num?)?.toDouble() ?? 0;
          final a = (it['amount'] as num?)?.toDouble() ?? (q * p);
          final u = it['unit']?.toString().trim().isNotEmpty == true
              ? it['unit'].toString().trim()
              : 'Kg';
          final name =
              it['item_name']?.toString().trim().isNotEmpty == true
                  ? it['item_name'].toString().trim()
                  : 'Item';
          totalQty += q;

          if (is80mm) {
            allBytes.addAll(gen.row([
              if (settings.printSNo)
                PosColumn(
                    width: 1,
                    text: '${i + 1}',
                    styles: const PosStyles(bold: true)),
              PosColumn(
                  width: settings.printSNo ? 5 : 6,
                  text: _clip(name, 14),
                  styles: const PosStyles(bold: true)),
              PosColumn(
                  width: 2,
                  text: '${_formatQty(q)}$u',
                  styles: const PosStyles(align: PosAlign.right)),
              PosColumn(
                  width: 2,
                  text: p.toStringAsFixed(dec),
                  styles: const PosStyles(align: PosAlign.right)),
              PosColumn(
                  width: 2,
                  text: a.toStringAsFixed(dec),
                  styles:
                      const PosStyles(bold: true, align: PosAlign.right)),
            ]));
          } else {
            // 58mm: two lines per item
            allBytes.addAll(txt(
              settings.printSNo
                  ? '${(i + 1).toString().padLeft(2)} ${_clip(name, 12)}'
                  : _clip(name, 14),
              styles: const PosStyles(bold: true),
            ));
            allBytes.addAll(txt(
              '   ${_formatQty(q)}$u'
              '  ${p.toStringAsFixed(dec).padLeft(6)}'
              '  ${a.toStringAsFixed(dec).padLeft(7)}',
            ));
          }
        }

        allBytes.addAll(gen.hr(ch: '-'));

        // ── SUMMARY ROW ───────────────────────────────────────────────
        if (settings.printTotalQuantity) {
          allBytes.addAll(gen.row([
            PosColumn(
                width: 4,
                text: 'Qty: ${_formatQty(totalQty)}',
                styles: const PosStyles(bold: true)),
            PosColumn(
                width: 4,
                text: 'Items: ${items.length}',
                styles:
                    const PosStyles(bold: true, align: PosAlign.center)),
            PosColumn(
                width: 4,
                text: val(subtotal),
                styles:
                    const PosStyles(bold: true, align: PosAlign.right)),
          ]));
        }

        allBytes.addAll(gen.hr(ch: '='));

        // ── TOTALS ────────────────────────────────────────────────────
        void addTotalRow(String label, String value, {bool bold = false}) {
          allBytes.addAll(gen.row([
            PosColumn(
                width: 8,
                text: label,
                styles: PosStyles(bold: bold)),
            PosColumn(
                width: 4,
                text: value,
                styles: PosStyles(bold: bold, align: PosAlign.right)),
          ]));
        }

        if (discount > 0 || shipping > 0 || packaging > 0) {
          addTotalRow('Subtotal', amt(subtotal));
        }
        if (discount > 0) {
          addTotalRow('Discount', '-${amt(discount)}');
        }
        if (shipping > 0) {
          addTotalRow('Shipping', amt(shipping));
        }
        if (packaging > 0) {
          addTotalRow('Packaging', amt(packaging));
        }

        allBytes.addAll(gen.hr(ch: '-'));
        addTotalRow('TOTAL', amt(total), bold: true);

        if (settings.printReceivedAmount && paid > 0) {
          addTotalRow('Paid', amt(paid));
        }
        if (settings.printBalanceAmount && balance > 0.009) {
          addTotalRow('Balance Due', amt(balance), bold: true);
        }
        if (prevBal.abs() > 0.009 && (curBal - balance).abs() > 0.01) {
          addTotalRow('Prev Balance', amt(prevBal));
          addTotalRow('Curr Balance', amt(curBal), bold: true);
        }

        // ── UPI / QR ──────────────────────────────────────────────────
        if (settings.showPaymentQr && settings.upiId.trim().isNotEmpty) {
          allBytes.addAll(gen.hr(ch: '-'));
          allBytes.addAll(txt(
            'Pay via UPI: ${settings.upiId.trim()}',
            styles: const PosStyles(align: PosAlign.center),
          ));
        }

        // ── DELIVERY ──────────────────────────────────────────────────
        if (deliveryName.isNotEmpty) {
          allBytes.addAll(gen.hr(ch: '-'));
          allBytes.addAll(txt(
            'Delivery: $deliveryName',
            styles: const PosStyles(align: PosAlign.center, bold: true),
          ));
        }

        // ── FOOTER ────────────────────────────────────────────────────
        if (settings.showFooterMessage &&
            settings.footerMessage.isNotEmpty) {
          allBytes.addAll(gen.hr(ch: '-'));
          allBytes.addAll(txt(
            settings.footerMessage.trim(),
            styles: const PosStyles(align: PosAlign.center, bold: true),
          ));
        }

        // Extra blank lines at end (user-configurable)
        final extraLines = settings.extraLinesAtPrintEnd.clamp(0, 10);
        if (extraLines > 0) {
          allBytes.addAll(gen.feed(extraLines));
        }

        allBytes.addAll(gen.feed(4));

        if (settings.autoCutPaper) {
          allBytes.addAll(gen.cut());
        }
      }

      return allBytes;
    });
  }

  // ── Print party account ───────────────────────────────────────────────────
  static Future<String?> printPartyAccount({
    required SettingsProvider settings,
    required String partyName,
    required String? partyPhone,
    required bool isSupplier,
    required double closingBalance,
    required List<Map<String, dynamic>> ledgerRows,
  }) {
    return _withPrinter(settings, (gen) async {
      final sym = settings.currencySymbol;
      String amt(num? v) => '$sym${(v ?? 0).toStringAsFixed(2)}';

      List<int> txt(String text, {PosStyles styles = const PosStyles()}) =>
          _txt(gen, text, styles: styles);

      final List<int> bytes = [];

      // ── INIT: hard reset + PC437 + cancel Kanji + left align ──────
      // MUST be first. Fixes blank print on Chinese printers in GBK mode.
      bytes.addAll(_initBytes());

      bytes.addAll(txt(
        settings.shopName.isEmpty
            ? AppConstants.shopName
            : settings.shopName,
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ));
      bytes.addAll(txt(
        'PARTY ACCOUNT STATEMENT',
        styles: const PosStyles(align: PosAlign.center),
      ));
      bytes.addAll(gen.hr(ch: '='));
      bytes.addAll(txt(partyName, styles: const PosStyles(bold: true)));
      if (partyPhone != null && partyPhone.isNotEmpty) {
        bytes.addAll(txt('Ph: $partyPhone'));
      }
      bytes.addAll(txt(isSupplier ? 'Type: Supplier' : 'Type: Customer'));
      bytes.addAll(gen.hr(ch: '-'));
      bytes.addAll(gen.row([
        PosColumn(
            width: 8,
            text: 'Closing Balance:',
            styles: const PosStyles(bold: true)),
        PosColumn(
            width: 4,
            text: amt(closingBalance),
            styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]));
      bytes.addAll(gen.hr(ch: '='));
      bytes.addAll(gen.feed(6));

      if (settings.autoCutPaper) {
        bytes.addAll(gen.cut());
      }

      return bytes;
    });
  }
}