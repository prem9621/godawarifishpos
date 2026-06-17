import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

class _InvoiceImageCard extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final List<Map<String, dynamic>> items;
  final SettingsProvider settings;

  const _InvoiceImageCard({
    required this.invoice,
    required this.items,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
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
    
    int totalItemsCount = 0;
    double totalDiscAmt = 0;

    return Container(
      width: 380,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Shop Name
          Text(
            shopName.toUpperCase(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            AppConstants.shopTagline,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
          if (settings.shopAddress.isNotEmpty)
            Text(
              settings.shopAddress,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          if (settings.shopPhone.isNotEmpty)
            Text(
              'Ph: ${settings.shopPhone}',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          const Divider(height: 16, thickness: 1, color: Colors.black),

          // Title
          const Text(
            'Bill Invoice',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const Divider(height: 16, thickness: 1, color: Colors.black),

          // Meta
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Invoice No: $invoiceNo', style: const TextStyle(fontSize: 11, color: Colors.black87)),
              Text('Date: $dateStr', style: const TextStyle(fontSize: 11, color: Colors.black87)),
            ],
          ),
          const Divider(height: 16, thickness: 1, color: Colors.black),

          // Customer
          Text(
            custName,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          if (custPhone.isNotEmpty)
            Text('Ph: $custPhone', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const Divider(height: 16, thickness: 1, color: Colors.black),

          // Items Table (Exact Vyapar format)
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
                
                totalItemsCount++;
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
                          SizedBox(width: 70, child: Text(price.toStringAsFixed(2), style: const TextStyle(fontSize: 11, color: Colors.black87), textAlign: TextAlign.right)),
                          SizedBox(width: 70, child: Text(rawAmt.toStringAsFixed(2), style: const TextStyle(fontSize: 11, color: Colors.black87), textAlign: TextAlign.right)),
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
                      if (discPct > 0 && discAmt > 0) ...[
                        Row(
                          children: [
                            const SizedBox(width: 40),
                            Expanded(
                              child: Text('    Disc.(${discPct.toStringAsFixed(0)}%)', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                            ),
                            SizedBox(width: 70, child: Text(':', style: TextStyle(fontSize: 10, color: Colors.grey.shade600), textAlign: TextAlign.right)),
                            SizedBox(width: 70, child: Text('-${_amt(discAmt)}', style: const TextStyle(fontSize: 10, color: Colors.black87), textAlign: TextAlign.right)),
                          ],
                        ),
                        Row(
                          children: [
                            const SizedBox(width: 40),
                            Expanded(
                              child: Text('    Final Amount', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                            ),
                            SizedBox(width: 70, child: Text(':', style: TextStyle(fontSize: 10, color: Colors.grey.shade600), textAlign: TextAlign.right)),
                            SizedBox(width: 70, child: Text(_amt(finalAmt), style: const TextStyle(fontSize: 10, color: Colors.black87), textAlign: TextAlign.right)),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ),
          const Divider(height: 16, thickness: 1, color: Colors.black),

          // Totals (Exact Vyapar format)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _colonTotalRow('Total', '$totalItemsCount'),
                if (totalDiscAmt > 0) _colonTotalRow('Total Disc.', '-$sym ${_amt(totalDiscAmt)}'),
                const Divider(height: 8, thickness: 1, color: Colors.black),
                _colonTotalRow('Total', '$sym ${_amt(total)}', bold: true),
                if (settings.printReceivedAmount) _colonTotalRow('Received', '$sym ${_amt(paid)}'),
                if (settings.printBalanceAmount) _colonTotalRow('Balance', '$sym ${_amt(balance)}'),
                if (prevBal != 0) _colonTotalRow('Previous Bal.', '$sym ${_amt(prevBal)}'),
                if (currBal != 0) _colonTotalRow('Current Bal.', '$sym ${_amt(currBal)}', bold: true),
              ],
            ),
          ),
          const Divider(height: 16, thickness: 1, color: Colors.black),

          // You Saved section
          if (totalDiscAmt > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _colonTotalRow('You Saved', '$sym ${_amt(totalDiscAmt)}', bold: true),
            ),
            const Divider(height: 16, thickness: 1, color: Colors.black),
          ],

          // Signature
          if (settings.printSignature) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    Container(width: 100, height: 1, color: Colors.black),
                    const SizedBox(height: 4),
                    Text('Received Sign', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
                Column(
                  children: [
                    Container(width: 100, height: 1, color: Colors.black),
                    const SizedBox(height: 4),
                    Text('Auth. Sign', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
            const Divider(height: 16, thickness: 1, color: Colors.black),
          ],

          // Delivery Boy
          if (deliveryBoyName.isNotEmpty) ...[
            Text(
              'Delivery by: $deliveryBoyName',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],

          // Footer
          Text(
            'Thank You Visit Again',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Fresh to your kitchen - Fish, Sea food, Chicken, Mutton',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
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
          const SizedBox(width: 40),
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
