import 'dart:io';
import 'dart:math' show min;
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr/qr.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/settings_provider.dart';

/// Thermal invoice printer that matches the exact Godawari Fish hard-copy receipt.
/// Supports logo printing via chunked raster bitmap, and formats receipts
/// for both 58mm (32 chars) and 80mm (48 chars) thermal paper.
class ThermalInvoicePrinter {
  ThermalInvoicePrinter._();

  // ── Permissions ────────────────────────────────────────────────────────────
  static Future<String?> _ensurePermissions() async {
    if (!Platform.isAndroid) return null;
    final c = await Permission.bluetoothConnect.request();
    if (!c.isGranted) return 'Bluetooth connect permission required.';
    final sc = await Permission.bluetoothScan.request();
    if (!sc.isGranted) return 'Bluetooth scan permission required.';
    return null;
  }

  // ── Printer connection wrapper ────────────────────────────────────────────
  static Future<String?> _withPrinter(
    SettingsProvider settings,
    Future<void> Function(BlueThermalPrinter bt, int width) job,
  ) async {
    final addr = settings.bluetoothPrinter.trim();
    if (addr.isEmpty) return 'Choose a Bluetooth printer in Settings first.';

    final perm = await _ensurePermissions();
    if (perm != null) return perm;

    final bt = BlueThermalPrinter.instance;
    try {
      final bonded = await bt.getBondedDevices();
      BluetoothDevice? dev;
      for (final d in bonded) {
        if (d.address == addr) {
          dev = d;
          break;
        }
      }
      if (dev == null) return 'Saved printer not found.';
      if ((await bt.isConnected) != true) await bt.connect(dev);

      // 80mm = 48 chars, 76mm (3 inch) = 48 chars, 58mm = 32 chars
      final width = settings.thermalPaperWidthMm >= 76 ? 48 : 32;

      // Full reset before every print
      await bt.writeBytes(Uint8List.fromList([0x1b, 0x40]));
      await Future.delayed(const Duration(milliseconds: 400));
      await bt.writeBytes(Uint8List.fromList([0x1b, 0x74, 0x00]));
      await bt.writeBytes(Uint8List.fromList([0x1c, 0x2e]));
      await bt.writeBytes(Uint8List.fromList([0x1b, 0x32]));
      await Future.delayed(const Duration(milliseconds: 150));

      await job(bt, width);

      // Feed for tear-off
      await bt.writeBytes(
          Uint8List.fromList([0x0a, 0x0a, 0x0a, 0x0a, 0x0a, 0x0a]));
      if (settings.autoCutPaper) {
        await bt.writeBytes(Uint8List.fromList([0x1d, 0x56, 0x00]));
      }
      return null;
    } catch (e) {
      return 'Print failed: $e';
    }
  }

  // ── Print one line ────────────────────────────────────────────────────────
  static Future<void> _p(
    BlueThermalPrinter bt,
    String text, {
    int size = 0,
    int align = 0,
    bool bold = false,
  }) async {
    final libSize = (bold && size == 0) ? 1 : size;
    await bt.printCustom(text, libSize, align);
    await Future.delayed(const Duration(milliseconds: 80));
  }

  static Future<void> _raw(BlueThermalPrinter bt, List<int> bytes) async {
    await bt.writeBytes(Uint8List.fromList(bytes));
    await Future.delayed(const Duration(milliseconds: 40));
  }

  // ── Layout helpers ────────────────────────────────────────────────────────
  static String _line(int w) => '-' * w;
  static String _dline(int w) => '=' * w;

  static String _lr(String left, String right, int width) {
    final space = width - left.length - right.length;
    if (space < 1) return '$left $right';
    return '$left${' ' * space}$right';
  }

  static String _threeCol(String l, String c, String r, int width) {
    final rem = width - l.length - r.length;
    if (rem <= c.length) return _lr(l, r, width);
    final pad = rem - c.length;
    return '$l${' ' * (pad ~/ 2)}$c${' ' * (pad - pad ~/ 2)}$r';
  }

  static String _amt(double v) => v.toStringAsFixed(2);

  static String _qty(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  // ── Total line: label flush-left, value flush-right ───────────────────────
  // No leading spaces, no colon — clean Vyapar-style alignment
  static String _totalLine(String label, String value, int width) {
    final spaces = width - label.length - value.length;
    if (spaces < 1) return '$label $value';
    return '$label${' ' * spaces}$value';
  }

  // ── Four-column row with fixed widths ─────────────────────────────────────
  // Col1 (S.No): 4  |  Col2 (Item): fills  |  Col3 (Price): 10 |  Col4 (Amt): 10
  static String _fourCol(
      String col1, String col2, String col3, String col4, int width) {
    const c1w = 4;
    const c3w = 10;
    const c4w = 10;
    final c2w = width - c1w - c3w - c4w;

    final c1 = col1.padRight(c1w);
    final c2 = col2.length > c2w ? col2.substring(0, c2w) : col2.padRight(c2w);
    final c3 = col3.padLeft(c3w);
    final c4 = col4.padLeft(c4w);

    return '$c1$c2$c3$c4';
  }

  // ── Logo printer (chunked, NO reset after) ───────────────────────────────
  static const int _btChunkSize = 3840;

  static Future<void> _printLogo(BlueThermalPrinter bt, int width) async {
    try {
      final data = await rootBundle.load('assets/images/log.png');
      final decoded = img.decodeImage(data.buffer.asUint8List());
      if (decoded == null) return;

      final logoW = width >= 40 ? 420 : 300;
      final resized = img.copyResize(decoded, width: logoW);

      final w = resized.width;
      final h = resized.height;
      final bytesPerRow = (w + 7) ~/ 8;

      final header = <int>[
        0x1b, 0x61, 0x01, // ESC a 1 – center
        0x1d, 0x76, 0x30, 0x00, // GS v 0 – raster image
        bytesPerRow & 0xff, (bytesPerRow >> 8) & 0xff, // width bytes
        h & 0xff, (h >> 8) & 0xff, // height dots
      ];

      final pixels = <int>[];
      for (int y = 0; y < h; y++) {
        for (int bx = 0; bx < bytesPerRow; bx++) {
          int byte = 0;
          for (int bit = 0; bit < 8; bit++) {
            final x = bx * 8 + bit;
            if (x < w) {
              final p = resized.getPixel(x, y);
              if ((0.299 * p.r + 0.587 * p.g + 0.114 * p.b) < 180) {
                byte |= (0x80 >> bit);
              }
            }
          }
          pixels.add(byte);
        }
      }

      final allBytes = Uint8List.fromList([...header, ...pixels]);
      final len = allBytes.length;

      for (int i = 0; i < len; i += _btChunkSize) {
        final end = min(i + _btChunkSize, len);
        await bt.writeBytes(allBytes.sublist(i, end));
        await Future.delayed(const Duration(milliseconds: 60));
      }

      // Wait for printer to finish rendering the raster image
      await Future.delayed(const Duration(milliseconds: 1500));

      // Feed line after raster image – required before text mode resumes
      await bt.writeBytes(Uint8List.fromList([0x0a]));
      await Future.delayed(const Duration(milliseconds: 100));

      // Restore left alignment. Do NOT send ESC @ here – it resets printer mid-job.
      await bt.writeBytes(Uint8List.fromList([0x1b, 0x61, 0x00]));
      await Future.delayed(const Duration(milliseconds: 80));
    } catch (_) {
      // Logo missing or decode error – skip silently
    }
  }

  // ── QR Code printer ───────────────────────────────────────────────────────
  static Future<void> _printQrBitmap(
    BlueThermalPrinter bt,
    String data,
    int width,
  ) async {
    try {
      final qrCode = QrCode(4, QrErrorCorrectLevel.L);
      qrCode.addData(data);
      final qrImage = QrImage(qrCode);

      final moduleSize = width >= 40 ? 5 : 4;
      const quietZone = 2;
      final imgSize =
          qrImage.moduleCount * moduleSize + quietZone * 2 * moduleSize;

      final qrImg = img.Image(width: imgSize, height: imgSize);
      for (int y = 0; y < imgSize; y++) {
        for (int x = 0; x < imgSize; x++) {
          qrImg.setPixel(x, y, img.ColorRgb8(255, 255, 255));
        }
      }

      for (int y = 0; y < qrImage.moduleCount; y++) {
        for (int x = 0; x < qrImage.moduleCount; x++) {
          if (qrImage.isDark(y, x)) {
            for (int dy = 0; dy < moduleSize; dy++) {
              for (int dx = 0; dx < moduleSize; dx++) {
                final px = (x + quietZone) * moduleSize + dx;
                final py = (y + quietZone) * moduleSize + dy;
                qrImg.setPixel(px, py, img.ColorRgb8(0, 0, 0));
              }
            }
          }
        }
      }

      final w = qrImg.width;
      final h = qrImg.height;
      final bytesPerRow = (w + 7) ~/ 8;

      final header = <int>[
        0x1b, 0x61, 0x01,
        0x1d, 0x76, 0x30, 0x00,
        bytesPerRow & 0xff, (bytesPerRow >> 8) & 0xff,
        h & 0xff, (h >> 8) & 0xff,
      ];

      final pixels = <int>[];
      for (int y = 0; y < h; y++) {
        for (int bx = 0; bx < bytesPerRow; bx++) {
          int byte = 0;
          for (int bit = 0; bit < 8; bit++) {
            final x = bx * 8 + bit;
            if (x < w) {
              final p = qrImg.getPixel(x, y);
              if ((0.299 * p.r + 0.587 * p.g + 0.114 * p.b) < 180) {
                byte |= (0x80 >> bit);
              }
            }
          }
          pixels.add(byte);
        }
      }

      final allBytes = Uint8List.fromList([...header, ...pixels]);
      final len = allBytes.length;
      const chunkSize = 3840;

      for (int i = 0; i < len; i += chunkSize) {
        final end = (i + chunkSize < len) ? i + chunkSize : len;
        await bt.writeBytes(allBytes.sublist(i, end));
        await Future.delayed(const Duration(milliseconds: 60));
      }

      await Future.delayed(const Duration(milliseconds: 800));
      await bt.writeBytes(Uint8List.fromList([0x0a]));
      await Future.delayed(const Duration(milliseconds: 100));
      await bt.writeBytes(Uint8List.fromList([0x1b, 0x61, 0x00]));
      await Future.delayed(const Duration(milliseconds: 80));
    } catch (_) {
      // QR generation failed – skip silently
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PRINT INVOICE
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<String?> printInvoice({
    required SettingsProvider settings,
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> items,
  }) {
    return _withPrinter(settings, (bt, width) async {
      final sym = settings.currencySymbol;
      final line = _line(width);

      // Dates
      final created =
          DateTime.tryParse(invoice['created_at']?.toString() ?? '') ??
              DateTime.now();
      final dateStr = DateFormat('dd/MM/yyyy').format(created);
      final invoiceNo = invoice['invoice_no']?.toString().trim() ?? '';

      // Financials
      final subtotal = (invoice['subtotal'] as num?)?.toDouble() ?? 0;
      final discount = (invoice['discount'] as num?)?.toDouble() ?? 0;
      final tax = (invoice['tax'] as num?)?.toDouble() ?? 0;
      final shipping = (invoice['shipping'] as num?)?.toDouble() ?? 0;
      final packaging = (invoice['packaging'] as num?)?.toDouble() ?? 0;
      final total = (invoice['total'] as num?)?.toDouble() ?? 0;
      final paid = (invoice['paid'] as num?)?.toDouble() ?? 0;
      final balance =
          (invoice['balance'] as num?)?.toDouble() ?? (total - paid);
      final prevBal = (invoice['previous_balance'] as num?)?.toDouble() ?? 0;
      final currBal = (invoice['current_balance'] as num?)?.toDouble() ??
          (balance + prevBal);
      final deliveryBoyName =
          invoice['delivery_boy_name']?.toString() ?? '';

      final shopName =
          settings.shopName.isEmpty ? AppConstants.shopName : settings.shopName;

      // ═════════════════════════════════════════════════════════════
      // 1. LOGO
      // ═════════════════════════════════════════════════════════════
      if (settings.printLogo) {
        await _printLogo(bt, width);
        // Separator line right after logo
        await _p(bt, line);
      }

      // ═════════════════════════════════════════════════════════════
      // 2. SHOP NAME — only printed when there is NO logo
      //    (logo already contains shop name & tagline)
      // ═════════════════════════════════════════════════════════════
      if (!settings.printLogo) {
        if (settings.printShopName) {
          await _p(bt, shopName.toUpperCase(), size: 2, align: 1);
        }
        await _p(bt, AppConstants.shopTagline, align: 1);
      }

      // ═════════════════════════════════════════════════════════════
      // 3. SHOP DETAILS (address & phone — always shown)
      // ═════════════════════════════════════════════════════════════
      if (settings.printShopAddress && settings.shopAddress.isNotEmpty) {
        await _p(bt, settings.shopAddress, align: 1);
      }
      if (settings.printShopPhone && settings.shopPhone.isNotEmpty) {
        await _p(bt, 'Ph: ${settings.shopPhone}', align: 1);
      }
      await _p(bt, line);

      // ═════════════════════════════════════════════════════════════
      // 4. INVOICE TYPE — bold, centred, uppercase
      // ═════════════════════════════════════════════════════════════
      await _p(bt, 'BILL  INVOICE', size: 1, align: 1, bold: true);
      await _p(bt, line);

      // ═════════════════════════════════════════════════════════════
      // 5. INVOICE META
      // ═════════════════════════════════════════════════════════════
      await _p(bt, _lr('Invoice No:  $invoiceNo', 'Date:  $dateStr', width));
      await _p(bt, line);

      // ═════════════════════════════════════════════════════════════
      // 6. CUSTOMER
      // ═════════════════════════════════════════════════════════════
      final custName =
          invoice['customer_name']?.toString() ?? 'Walk-in Customer';
      final custPhone = invoice['customer_phone']?.toString() ?? '';
      await _p(bt, custName, align: 1, bold: true);
      if (custPhone.isNotEmpty) {
        await _p(bt, 'Ph: $custPhone', align: 1);
      }
      await _p(bt, line);

      // ═════════════════════════════════════════════════════════════
      // 7. ITEMS TABLE HEADER
      // ═════════════════════════════════════════════════════════════
      if (width >= 40) {
        // 80mm — single header row, all four columns
        await _p(
            bt,
            _fourCol('#', 'Item Name', 'Price', 'Amount', width),
            bold: true);
      } else {
        // 58mm — two-line header
        await _p(bt, '#  Item Name', bold: true);
        await _p(bt, '   Price      Amt', bold: true);
      }
      await _p(bt, line);

      // ═════════════════════════════════════════════════════════════
      // 8. ITEMS
      // ═════════════════════════════════════════════════════════════
      int totalItemsCount = 0;
      double totalDiscAmt = 0;

      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final name = item['item_name']?.toString() ?? 'Item';
        final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
        final price = (item['price'] as num?)?.toDouble() ?? 0;
        final rawAmt = qty * price;
        final discPct = (item['discount_percent'] as num?)?.toDouble() ??
            (item['discount'] as num?)?.toDouble() ??
            0.0;
        final discAmt = (discPct > 0) ? (rawAmt * discPct / 100) : 0.0;
        final finalAmt = rawAmt - discAmt;
        final amt = (item['amount'] as num?)?.toDouble() ?? finalAmt;
        final unit = item['unit']?.toString() ?? 'Kg';
        final sNo = settings.printSNo ? '${i + 1}' : '';
        totalItemsCount++;
        totalDiscAmt += discAmt;

        if (width >= 40) {
          // ── 80mm: item name + qty inline ───────────────────────
          // e.g.  "1  Bonless Fish 3Kg     450.00   1350.00"
          final nameQty = '$name ${_qty(qty)}$unit';
          final sNoStr = settings.printSNo ? '${i + 1}' : '';
          await _p(
              bt,
              _fourCol(
                sNoStr,
                nameQty,
                price.toStringAsFixed(2),
                _amt(rawAmt),
                width,
              ));
          // Discount row (indented, only when applicable)
          if (discPct > 0 && discAmt > 0) {
            await _p(
                bt,
                _fourCol(
                  '',
                  '  Disc.(${discPct.toStringAsFixed(0)}%)',
                  '',
                  '-${_amt(discAmt)}',
                  width,
                ));
            await _p(
                bt,
                _fourCol(
                  '',
                  '  Final Amt',
                  '',
                  _amt(finalAmt),
                  width,
                ));
          }
        } else {
          // ── 58mm ───────────────────────────────────────────────
          final sNoPrefix = settings.printSNo ? '$sNo ' : '';
          await _p(bt, '$sNoPrefix$name');
          await _p(bt, '   ${_qty(qty)}$unit  @${price.toStringAsFixed(2)}  ${_amt(rawAmt)}');
          if (discPct > 0 && discAmt > 0) {
            await _p(bt, '   Disc.(${discPct.toStringAsFixed(0)}%) -${_amt(discAmt)}');
            await _p(bt, '   Final: ${_amt(finalAmt)}');
          }
        }
      }
      await _p(bt, line);

      // ═════════════════════════════════════════════════════════════
      // 9. TOTALS — flush-left label, flush-right value
      // ═════════════════════════════════════════════════════════════
      await _p(bt, _totalLine('Total Items', '$totalItemsCount', width));

      if (totalDiscAmt > 0) {
        await _p(bt,
            _totalLine('Total Disc.', '-$sym ${_amt(totalDiscAmt)}', width));
      }

      await _p(
          bt,
          _totalLine('Total', '$sym ${_amt(total)}', width),
          bold: true);

      if (settings.printReceivedAmount) {
        await _p(bt, _totalLine('Received', '$sym ${_amt(paid)}', width));
      }

      if (settings.printBalanceAmount) {
        await _p(bt, _totalLine('Balance', '$sym ${_amt(balance)}', width));
      }

      if (prevBal != 0) {
        await _p(bt,
            _totalLine('Previous Bal.', '$sym ${_amt(prevBal)}', width));
        await _p(
            bt,
            _totalLine('Current Bal.', '$sym ${_amt(currBal)}', width),
            bold: true);
      }

      await _p(bt, line);

      // "You Saved" section
      if (totalDiscAmt > 0) {
        await _p(
            bt,
            _totalLine('You Saved', '$sym ${_amt(totalDiscAmt)}', width),
            bold: true);
        await _p(bt, line);
      }

      // ═════════════════════════════════════════════════════════════
      // 10. SIGNATURE — extra blank lines for writing room
      // ═════════════════════════════════════════════════════════════
      if (settings.printSignature) {
        await _p(bt, ''); // breathing space
        await _p(bt, ''); // breathing space
        await _p(bt, ''); // breathing space
        // Underlines for signing
        if (width >= 40) {
          // 80mm: longer lines with gap
          await _p(bt, _lr('___________________', '___________________', width));
        } else {
          await _p(bt, _lr('----------', '----------', width));
        }
        await _p(bt, _lr('Received Sign', 'Auth. Sign', width));
        await _p(bt, line);
      }

      // ═════════════════════════════════════════════════════════════
      // 11. FOOTER
      // ═════════════════════════════════════════════════════════════
      if (deliveryBoyName.isNotEmpty) {
        await _p(bt, 'Delivery by: $deliveryBoyName', align: 1, bold: true);
      }
      if (settings.showFooterMessage && settings.footerMessage.isNotEmpty) {
        await _p(bt, settings.footerMessage, align: 1);
      }
      // Single "Thank You" — bold large
      await _p(bt, 'Thank You Visit Again', align: 1, bold: true, size: 1);
      await _p(bt,
          'Fresh to your kitchen - Fish, Sea food, Chicken, Mutton',
          align: 1);
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PRINT PARTY ACCOUNT STATEMENT
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<String?> printPartyAccount({
    required SettingsProvider settings,
    required String partyName,
    required String? partyPhone,
    required bool isSupplier,
    required double closingBalance,
    required List<Map<String, dynamic>> ledgerRows,
  }) {
    return _withPrinter(settings, (bt, width) async {
      final sym = settings.currencySymbol;
      final line = _line(width);
      final dLine = _dline(width);
      final shopName =
          settings.shopName.isEmpty ? AppConstants.shopName : settings.shopName;

      await _p(bt, shopName.toUpperCase(), size: 2, align: 1);
      await _p(bt, 'PARTY STATEMENT', size: 1, align: 1);
      await _p(bt, dLine);

      if (settings.printLogo) await _printLogo(bt, width);

      await _p(bt, 'Party: ${partyName.toUpperCase()}', bold: true);
      if (partyPhone != null && partyPhone.isNotEmpty) {
        await _p(bt, 'Phone: $partyPhone');
      }
      await _p(bt, 'Type : ${isSupplier ? 'Supplier' : 'Customer'}');
      await _p(bt,
          'Date : ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');
      await _p(bt, line);

      if (ledgerRows.isNotEmpty) {
        await _p(bt, 'Date       Description     Amount', bold: true);
        await _p(bt, line);
        for (final r in ledgerRows) {
          final dateStr = r['date']?.toString() ?? '';
          final desc =
              (r['line']?.toString() ?? r['description']?.toString() ?? '');
          final amount = (r['amount'] as num?)?.toDouble() ?? 0;
          final shortDate =
              dateStr.length > 5 ? dateStr.substring(0, 5) : dateStr;
          final shortDesc = desc.length > 14 ? desc.substring(0, 14) : desc;
          await _p(bt,
              _lr('$shortDate $shortDesc', amount.toStringAsFixed(2), width));
        }
        await _p(bt, line);
      }

      await _p(
          bt,
          _totalLine(
              'CLOSING BALANCE',
              '$sym ${closingBalance.toStringAsFixed(2)}',
              width),
          size: 1,
          bold: true);
      await _p(bt, dLine);
      await _p(bt, 'Powered By Godawari Fish', align: 1);
      if (settings.showFooterMessage) {
        await _p(bt, settings.footerMessage, align: 1);
      }
    });
  }
}