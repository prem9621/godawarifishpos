import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/settings_provider.dart';

class InvoiceImageGenerator {
  static Future<void> shareInvoiceImage({
    required BuildContext context,
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> items,
    required SettingsProvider settings,
  }) async {
    final bytes = await _captureInvoiceWidget(
      context: context,
      invoice: invoice,
      items: items,
      settings: settings,
    );
    if (bytes == null) throw Exception('Failed to generate image');
    final invoiceNo = invoice['invoice_no']?.toString() ?? 'invoice';
    final file = await _saveImageToTemp(bytes, invoiceNo);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Bill Invoice $invoiceNo from ${settings.shopName.isEmpty ? AppConstants.shopName : settings.shopName}',
    );
  }

  static Future<Uint8List?> _captureInvoiceWidget({
    required BuildContext context,
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> items,
    required SettingsProvider settings,
  }) async {
    final completer = Completer<Uint8List?>();
    final globalKey = GlobalKey();

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -5000,
        top: -5000,
        child: RepaintBoundary(
          key: globalKey,
          child: _InvoiceImageCard(
            invoice: invoice,
            items: items,
            settings: settings,
          ),
        ),
      ),
    );

    overlay.insert(entry);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await Future.delayed(const Duration(milliseconds: 300));
        final boundary = globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) {
          completer.complete(null);
          entry.remove();
          return;
        }
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        completer.complete(byteData?.buffer.asUint8List());
      } catch (e) {
        completer.complete(null);
      } finally {
        entry.remove();
      }
    });

    return completer.future;
  }

  static Future<File> _saveImageToTemp(Uint8List bytes, String name) async {
    final dir = await getTemporaryDirectory();
    final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File('${dir.path}/${safeName}_godawari.png');
    await file.writeAsBytes(bytes);
    return file;
  }
}

class _InvoiceImageCard extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final List<Map<String, dynamic>> items;
  final SettingsProvider settings;

  const _InvoiceImageCard({
    required this.invoice,
    required this.items,
    required this.settings,
  });

  @override
  State<_InvoiceImageCard> createState() => _InvoiceImageCardState();
}

class _InvoiceImageCardState extends State<_InvoiceImageCard> {
  ui.Image? _logoImage;

  @override
  void initState() {
    super.initState();
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/images/log.png');
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _logoImage = frame.image;
        });
      }
    } catch (e) {
      debugPrint('Failed to load logo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sym = widget.settings.currencySymbol;
    final shopName = widget.settings.shopName.isEmpty ? AppConstants.shopName : widget.settings.shopName;
    final created = DateTime.tryParse(widget.invoice['created_at']?.toString() ?? '') ?? DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(created);
    final timeStr = DateFormat('hh:mm a').format(created);
    final invoiceNo = widget.invoice['invoice_no']?.toString() ?? '';
    final custName = widget.invoice['customer_name']?.toString() ?? 'Walk-in Customer';
    final custPhone = widget.invoice['customer_phone']?.toString() ?? '';

    final total = (widget.invoice['total'] as num?)?.toDouble() ?? 0;
    final paid = (widget.invoice['paid'] as num?)?.toDouble() ?? 0;
    final balance = (widget.invoice['balance'] as num?)?.toDouble() ?? (total - paid);
    final prevBal = (widget.invoice['previous_balance'] as num?)?.toDouble() ?? 0;
    final currBal = (widget.invoice['current_balance'] as num?)?.toDouble() ?? (balance + prevBal);
    final shipping = (widget.invoice['shipping'] as num?)?.toDouble() ?? 0;
    final packaging = (widget.invoice['packaging'] as num?)?.toDouble() ?? 0;
    final deliveryBoyName = widget.invoice['delivery_boy_name']?.toString() ?? '';
    
    double totalQty = 0;
    int totalItemsCount = widget.items.length;
    double totalDiscAmt = 0;
    double subtotal = 0;

    for (var item in widget.items) {
      final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
      final price = (item['price'] as num?)?.toDouble() ?? 0;
      totalQty += qty;
      subtotal += qty * price;
    }

    return Container(
      width: 380,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo
          if (_logoImage != null) ...[
            Center(
              child: RawImage(
                image: _logoImage!,
                width: 180,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Shop Details
          Text(
            AppConstants.shopAddress,
            style: const TextStyle(fontSize: 10, color: Colors.black87),
          ),
          if (AppConstants.shopPhone.isNotEmpty)
            Text(
              'Ph.No.: ${AppConstants.shopPhone}',
              style: const TextStyle(fontSize: 10, color: Colors.black87),
            ),
          if (AppConstants.shopEmail.isNotEmpty)
            Text(
              'Email: ${AppConstants.shopEmail}',
              style: const TextStyle(fontSize: 10, color: Colors.black87),
            ),
          const SizedBox(height: 12),

          // Title
          const Center(
            child: Text(
              'Bill Invoice',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          const Divider(height: 12, thickness: 1, color: Colors.black),

          // Meta (Invoice No, Date, Time)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Invoice No: $invoiceNo', style: const TextStyle(fontSize: 11, color: Colors.black87)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Date: $dateStr', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                  Text('Time: $timeStr', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                ],
              ),
            ],
          ),
          const Divider(height: 12, thickness: 1, color: Colors.black),

          // Bill To
          const Text(
            'Bill To:',
            style: TextStyle(fontSize: 11, color: Colors.black87),
          ),
          Center(
            child: Text(
              custName.toUpperCase(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ),
          const Divider(height: 12, thickness: 1, color: Colors.black),

          // Items Table
          Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 40, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    const Expanded(child: Text('Item Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 70, child: Text('Price', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                    SizedBox(width: 70, child: Text('Amount', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Colors.black),
              ...widget.items.asMap().entries.map((entry) {
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

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(width: 40, child: Text('${i + 1}', style: const TextStyle(fontSize: 11, color: Colors.black87))),
                          Expanded(
                            child: Text(name, style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500)),
                          ),
                          SizedBox(width: 70, child: Text('$sym${price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.black87), textAlign: TextAlign.right)),
                          SizedBox(width: 70, child: Text('$sym${rawAmt.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.black87), textAlign: TextAlign.right)),
                        ],
                      ),
                      Row(
                        children: [
                          const SizedBox(width: 40),
                          Expanded(
                            child: Text('    ${_qtyStr(qty)}$unit', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
          const Divider(height: 12, thickness: 1, color: Colors.black),

          // Qty & Items
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Qty: ${_qtyStr(totalQty)}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
              Text('Items: $totalItemsCount', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
              Text('$sym${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
            ],
          ),
          const Divider(height: 12, thickness: 1, color: Colors.black),

          // Totals
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _colonTotalRow('Subtotal', '$sym${_amt(subtotal)}'),
                if (shipping > 0) _colonTotalRow('Shipping', '$sym${_amt(shipping)}'),
                if (packaging > 0) _colonTotalRow('Packaging', '$sym${_amt(packaging)}'),
                _colonTotalRow('Paid', '$sym${_amt(paid)}'),
                const Divider(height: 8, thickness: 1, color: Colors.black),
                _colonTotalRow('Total', '$sym${_amt(total)}', bold: true),
                _colonTotalRow('Balance', '$sym${_amt(balance)}'),
                _colonTotalRow('Current Bal.', '$sym${_amt(currBal)}'),
                _colonTotalRow('Previous Bal.', '$sym${_amt(prevBal)}'),
              ],
            ),
          ),
          const Divider(height: 12, thickness: 1, color: Colors.black),

          // Terms & Conditions
          const Text(
            'Terms & Conditions',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const Text('----', style: TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 16),

          // Received Sign
          const Text('....... Received Sign .......', style: TextStyle(fontSize: 10, color: Colors.black87)),
          const SizedBox(height: 4),

          // Delivery by
          if (deliveryBoyName.isNotEmpty)
            Text('Delivery by... $deliveryBoyName', style: const TextStyle(fontSize: 10, color: Colors.black87)),
          const SizedBox(height: 4),

          const Divider(height: 12, thickness: 1, color: Colors.black),

          // Footer
          const Center(
            child: Text(
              'Thank You Visit Again',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.normal,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _colonTotalRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label :',
            style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: Colors.black87),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  static String _amt(double v) {
    return v.toStringAsFixed(2);
  }

  static String _qtyStr(double qty) {
    if (qty == qty.truncateToDouble()) return qty.toInt().toString();
    return qty.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
}
