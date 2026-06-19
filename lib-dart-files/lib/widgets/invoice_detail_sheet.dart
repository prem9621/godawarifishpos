import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/billing_provider.dart';
import '../screens/billing/new_bill_screen.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';
import '../database/database_helper.dart';
import '../providers/settings_provider.dart';
import '../core/receipt/thermal_invoice_printer.dart';
import '../core/receipt/invoice_pdf_generator.dart';
import '../core/receipt/invoice_image_generator.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED HELPER — extract items safely with DB fallback
// ─────────────────────────────────────────────────────────────────────────────
Future<List<Map<String, dynamic>>> _extractItems(
  Map<String, dynamic> inv,
  int invoiceId,
) async {
  final rawItems = inv['items'];
  final items = <Map<String, dynamic>>[];
  if (rawItems is List && rawItems.isNotEmpty) {
    for (final e in rawItems) {
      if (e is Map) items.add(Map<String, dynamic>.from(e));
    }
  }
  if (items.isNotEmpty) {
    debugPrint('✅ _extractItems: ${items.length} items from invoice map');
    return items;
  }
  debugPrint('⚠️ _extractItems: map empty, querying DB for invoice_id=$invoiceId');
  try {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
    final result = rows.map((e) => Map<String, dynamic>.from(e)).toList();
    debugPrint('✅ _extractItems: DB fallback got ${result.length} items');
    return result;
  } catch (e) {
    debugPrint('❌ _extractItems: DB fallback failed: $e');
    return [];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PUBLIC: Show invoice detail sheet
// ─────────────────────────────────────────────────────────────────────────────
Future<void> showInvoiceDetailSheet(
  BuildContext context,
  int invoiceId, {
  bool readOnly = false,
  VoidCallback? onDeleted,
  VoidCallback? onEdited,
}) async {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const SizedBox(
      height: 200,
      child: Center(child: CircularProgressIndicator()),
    ),
  );

  final db = DatabaseHelper.instance;
  Map<String, dynamic>? inv;
  try {
    inv = await db.getInvoiceById(invoiceId);
  } catch (e) {
    debugPrint('❌ getInvoiceById error: $e');
  }

  if (!context.mounted) return;
  Navigator.of(context).pop();

  if (inv == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invoice not found'), backgroundColor: Colors.red),
    );
    return;
  }

  final items = await _extractItems(inv, invoiceId);
  final settings = context.read<SettingsProvider>();
  final sym = settings.currencySymbol;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return _InvoiceDetailBody(
        invoiceId: invoiceId,
        invoice: inv!,
        items: items,
        settings: settings,
        sym: sym,
        readOnly: readOnly,
        onDeleted: () {
          Navigator.of(ctx).pop();
          onDeleted?.call();
        },
        onEdited: () {
          Navigator.of(ctx).pop();
          onEdited?.call();
        },
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  PUBLIC: Auto-popup receipt after save
// ─────────────────────────────────────────────────────────────────────────────
Future<void> showReceiptPopup(BuildContext context, int invoiceId) async {
  if (!context.mounted) return;

  final db = DatabaseHelper.instance;
  Map<String, dynamic>? inv;
  try {
    inv = await db.getInvoiceById(invoiceId);
  } catch (e) {
    debugPrint('❌ showReceiptPopup error: $e');
    return;
  }
  if (inv == null || !context.mounted) return;

  final items = await _extractItems(inv, invoiceId);
  final settings = context.read<SettingsProvider>();

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dctx) => _ReceiptPopupDialog(
      invoice: inv!,
      items: items,
      settings: settings,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  RECEIPT POPUP DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class _ReceiptPopupDialog extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final List<Map<String, dynamic>> items;
  final SettingsProvider settings;

  const _ReceiptPopupDialog({
    required this.invoice,
    required this.items,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final sym = settings.currencySymbol;
    final total = (invoice['total'] as num?)?.toDouble() ?? 0;
    final paid = (invoice['paid'] as num?)?.toDouble() ?? 0;
    final balance = (invoice['balance'] as num?)?.toDouble() ?? 0;
    final isPaid = balance <= 0.009;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Success header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 16, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade600, Colors.green.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bill Saved!',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                          Text(invoice['invoice_no'] as String? ?? '',
                              style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      visualDensity: VisualDensity.compact,
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    _headerChip('Total', '$sym${total.toStringAsFixed(0)}', Colors.white),
                    const SizedBox(width: 8),
                    _headerChip('Paid', '$sym${paid.toStringAsFixed(0)}', Colors.white.withValues(alpha: 0.85)),
                    const SizedBox(width: 8),
                    _headerChip(
                      isPaid ? 'Settled ✓' : 'Due',
                      isPaid ? '' : '$sym${balance.toStringAsFixed(0)}',
                      isPaid ? Colors.white.withValues(alpha: 0.70) : Colors.red.shade100,
                    ),
                  ]),
                ],
              ),
            ),

            // ── Scrollable body ─────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blue.shade600,
                        child: Text(
                          _initial(invoice['customer_name'] as String?),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          invoice['customer_name'] as String? ?? 'Walk-in Customer',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (invoice['status'] != null)
                        _StatusChip(status: invoice['status'] as String),
                    ]),
                    const SizedBox(height: 14),

                    if (invoice['status'] != 'paid') ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final bill = context.read<BillingProvider>();
                            bill.startEditing(invoice);
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const NewBillScreen()));
                          },
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: const Text('Edit / Add Payment'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryBlue,
                            side: BorderSide(color: Colors.blue.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(children: [
                              Expanded(child: Text('ITEM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5))),
                              Text('QTY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5)),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 70,
                                child: Text('AMT', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5)),
                              ),
                            ]),
                          ),
                          const Divider(height: 1),
                          ...items.asMap().entries.map((entry) {
                            final i = entry.key;
                            final row = entry.value;
                            final name = row['item_name'] as String? ?? '';
                            final qty = (row['quantity'] as num?)?.toDouble() ?? 0;
                            final unit = row['unit'] as String? ?? 'Kg';
                            final amt = (row['amount'] as num?)?.toDouble() ?? 0;
                            return Container(
                              decoration: BoxDecoration(
                                color: i.isEven ? Colors.white : Colors.grey.shade50,
                                border: i < items.length - 1
                                    ? Border(bottom: BorderSide(color: Colors.grey.shade100))
                                    : null,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              child: Row(children: [
                                Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87), overflow: TextOverflow.ellipsis)),
                                Text('${_formatQtyShort(qty)} $unit', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 70,
                                  child: Text('$sym${amt.toStringAsFixed(0)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
                                ),
                              ]),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(children: [
                        _popupRow('Subtotal', '$sym${(invoice['subtotal'] as num? ?? 0).toStringAsFixed(2)}'),
                        if ((invoice['discount'] as num? ?? 0) > 0)
                          _popupRow('Discount', '- $sym${(invoice['discount'] as num).toStringAsFixed(2)}', color: Colors.green),
                        if ((invoice['tax'] as num? ?? 0) > 0)
                          _popupRow('Tax', '$sym${(invoice['tax'] as num).toStringAsFixed(2)}'),
                        if ((invoice['shipping'] as num? ?? 0) > 0)
                          _popupRow('Shipping', '$sym${(invoice['shipping'] as num).toStringAsFixed(2)}'),
                        if ((invoice['packaging'] as num? ?? 0) > 0)
                          _popupRow('Packaging', '$sym${(invoice['packaging'] as num).toStringAsFixed(2)}'),
                        const Divider(height: 16),
                        _popupRow('TOTAL', '$sym${total.toStringAsFixed(2)}', bold: true, color: Colors.blue.shade700),
                        const SizedBox(height: 4),
                        _popupRow('Paid', '$sym${paid.toStringAsFixed(2)}', color: Colors.green.shade700),
                        if (balance > 0.009) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Balance Due', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red.shade800, fontSize: 13)),
                                Text('$sym${balance.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.red.shade700, fontSize: 14)),
                              ],
                            ),
                          ),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Print button in popup ───────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.print_rounded),
                    label: const Text('Print Receipt'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: Colors.blue.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      debugPrint('🖨️ POPUP PRINT BUTTON PRESSED');
                      try {
                        final err = await ThermalInvoicePrinter.printInvoice(
                          settings: settings,
                          invoice: invoice,
                          items: items,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(err ?? '✅ Sent to printer'),
                              backgroundColor: err == null ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      } catch (e, st) {
                        debugPrint('❌ POPUP PRINT CRASH: $e\n$st');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Print error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close', style: TextStyle(color: Colors.grey.shade600)),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w500)),
            if (value.isNotEmpty)
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _popupRow(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.normal, color: color ?? Colors.black87)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.normal, color: color ?? Colors.black87)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────────────────────
String _initial(String? name) {
  if (name == null || name.isEmpty) return '?';
  return name[0].toUpperCase();
}

String _formatDate(String? raw) {
  if (raw == null) return '';
  try {
    final dt = DateTime.parse(raw);
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year}  $h:$min';
  } catch (_) {
    return raw;
  }
}

String _formatQtyShort(double qty) {
  if (qty == qty.truncateToDouble()) return qty.toInt().toString();
  return qty.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
}

Widget _kv(String label, dynamic value, {bool bold = false, bool large = false, String sym = '₹', Color? color}) {
  final String v;
  if (value is num) {
    v = AppUtils.formatCurrency(value.toDouble(), symbol: sym);
  } else {
    v = value?.toString() ?? '—';
  }
  final style = TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: large ? 18 : 14, color: color);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(v, style: style)],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (status.toLowerCase()) {
      case 'paid':
        bg = Colors.green.shade100; fg = Colors.green.shade800; break;
      case 'partial':
        bg = Colors.orange.shade100; fg = Colors.orange.shade800; break;
      case 'unpaid':
        bg = Colors.red.shade100; fg = Colors.red.shade800; break;
      default:
        bg = Colors.grey.shade200; fg = Colors.grey.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : '',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  INVOICE DETAIL BODY  (bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────
class _InvoiceDetailBody extends StatefulWidget {
  final int invoiceId;
  final Map<String, dynamic> invoice;
  final List<Map<String, dynamic>> items;
  final SettingsProvider settings;
  final String sym;
  final bool readOnly;
  final VoidCallback? onDeleted;
  final VoidCallback? onEdited;

  const _InvoiceDetailBody({
    required this.invoiceId,
    required this.invoice,
    required this.items,
    required this.settings,
    required this.sym,
    this.readOnly = false,
    this.onDeleted,
    this.onEdited,
  });

  @override
  State<_InvoiceDetailBody> createState() => _InvoiceDetailBodyState();
}

class _InvoiceDetailBodyState extends State<_InvoiceDetailBody> {
  late Map<String, dynamic> inv;
  late List<Map<String, dynamic>> items;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    inv = widget.invoice;
    items = widget.items;
  }

  Future<void> _shareInvoice() async {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.image_outlined, color: Colors.teal),
              title: const Text('Share as Image'),
              subtitle: const Text('Generate PNG receipt and share'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await InvoiceImageGenerator.shareInvoiceImage(
                    context: context,
                    invoice: inv,
                    items: items,
                    settings: widget.settings,
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Share failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
              title: const Text('Share as PDF'),
              subtitle: const Text('Generate PDF invoice and share'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await InvoicePdfGenerator.shareInvoicePdf(
                    invoice: inv,
                    items: items,
                    settings: widget.settings,
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Share failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteInvoice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Bill?'),
        content: Text('This will permanently delete bill ${inv['invoice_no']}. Stock will NOT be restored automatically.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await DatabaseHelper.instance.deleteInvoice(widget.invoiceId);
      widget.onDeleted?.call();
    } catch (e) {
      setState(() => _deleting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.80,
      maxChildSize: 0.96,
      minChildSize: 0.45,
      builder: (_, scroll) {
        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inv['invoice_no'] as String? ?? '',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(_formatDate(inv['created_at'] as String?),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
              _StatusChip(status: inv['status'] as String? ?? ''),
            ]),
            const SizedBox(height: 12),

            // ── Customer card ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.indigo.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.primaryBlue,
                  child: Text(_initial(inv['customer_name'] as String?),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(inv['customer_name'] as String? ?? 'Walk-in Customer',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black87),
                          overflow: TextOverflow.ellipsis),
                      if ((inv['customer_phone'] as String?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          Icon(Icons.phone_outlined, size: 12, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(inv['customer_phone'] as String,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                        ]),
                      ],
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 18),

            // ── Items header ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Expanded(flex: 3, child: Text('ITEM', style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                SizedBox(width: 70, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                SizedBox(width: 80, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
              ]),
            ),
            const SizedBox(height: 4),

            // ── Items list ───────────────────────────────────────────────
            ...items.map((row) {
              final qty = (row['quantity'] as num?)?.toDouble() ?? 0;
              final price = (row['price'] as num?)?.toDouble() ?? 0;
              final amount = (row['amount'] as num?)?.toDouble() ?? (qty * price);
              final unit = row['unit'] as String? ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(
                    flex: 3,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(row['item_name'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
                          overflow: TextOverflow.ellipsis, maxLines: 1),
                      const SizedBox(height: 2),
                      Text('${widget.sym}${price.toStringAsFixed(2)} / $unit',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ]),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text('${_formatQtyShort(qty)} $unit', textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500)),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(AppUtils.formatCurrency(amount, symbol: widget.sym), textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black87)),
                  ),
                ]),
              );
            }),

            const Divider(height: 20),
            _kv('Subtotal', inv['subtotal'], sym: widget.sym),
            if ((inv['discount'] as num?)?.toDouble() != 0)
              _kv('Discount', inv['discount'], sym: widget.sym, color: Colors.green),
            if ((inv['tax'] as num?)?.toDouble() != 0)
              _kv('Tax', inv['tax'], sym: widget.sym),
            if ((inv['shipping'] as num?)?.toDouble() != 0)
              _kv('Shipping', inv['shipping'], sym: widget.sym),
            if ((inv['packaging'] as num?)?.toDouble() != 0)
              _kv('Packaging', inv['packaging'], sym: widget.sym),
            const Divider(height: 12),
            _kv('Total', inv['total'], sym: widget.sym, bold: true, large: true),
            _kv('Paid', inv['paid'], sym: widget.sym, color: Colors.green),
            _kv('Due', inv['balance'], sym: widget.sym,
                color: ((inv['balance'] as num?)?.toDouble() ?? 0) > 0 ? Colors.red : null),
            if ((inv['previous_balance'] as num?)?.toDouble() != 0)
              _kv('Previous Balance', inv['previous_balance'], sym: widget.sym, color: Colors.orange),
            if ((inv['current_balance'] as num?)?.toDouble() != 0)
              _kv('Current Balance', inv['current_balance'], sym: widget.sym, bold: true,
                  color: ((inv['current_balance'] as num?)?.toDouble() ?? 0) > 0 ? Colors.red : Colors.green),

            if ((inv['notes'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber.shade700),
                  const SizedBox(width: 6),
                  Expanded(child: Text(inv['notes'] as String,
                      style: TextStyle(fontSize: 13, color: Colors.amber.shade900))),
                ]),
              ),
            ],

            const SizedBox(height: 20),

            // ── Print button ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.print_rounded),
                label: const Text('Print Receipt'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: Colors.blue.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  debugPrint('🖨️ PRINT BUTTON PRESSED');
                  try {
                    final err = await ThermalInvoicePrinter.printInvoice(
                      settings: widget.settings,
                      invoice: inv,
                      items: items,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(err ?? '✅ Receipt sent to printer'),
                        backgroundColor: err != null ? Colors.red : Colors.green,
                      ),
                    );
                  } catch (e, st) {
                    debugPrint('❌ PRINT CRASH: $e\n$st');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Print error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 10),

            // ── Share | Edit | Delete ────────────────────────────────────
            if (!widget.readOnly) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: Colors.teal,
                      side: BorderSide(color: Colors.teal.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _shareInvoice,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: Colors.blue.shade700,
                      side: BorderSide(color: Colors.blue.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      final bill = context.read<BillingProvider>();
                      bill.startEditing(inv);
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NewBillScreen()));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: _deleting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _deleting ? null : _deleteInvoice,
                  ),
                ),
              ]),
            ],
          ],
        );
      },
    );
  }
}