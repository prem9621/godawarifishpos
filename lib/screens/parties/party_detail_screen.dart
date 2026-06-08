import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/export/party_account_export.dart';
import '../../core/printing/thermal_invoice_printer.dart';
import '../../database/database_helper.dart';
import '../../models/customer_model.dart';
import '../../providers/billing_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/invoice_detail_sheet.dart';
import '../billing/new_bill_screen.dart';
import '../purchase/purchase_screen.dart';

class PartyDetailScreen extends StatefulWidget {
  const PartyDetailScreen({super.key, required this.customerId});
  final int customerId;
  @override
  State<PartyDetailScreen> createState() => _PartyDetailScreenState();
}

class _PartyDetailScreenState extends State<PartyDetailScreen> {
  final _db = DatabaseHelper.instance;
  CustomerModel? _customer;
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _purchases = [];
  bool _loading = true;

  static const _red = Color(0xFFE31E24);
  static const _navy = Color(0xFF1A237E);
  static final _historyStart = DateTime(2000);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final row = await _db.getCustomerById(widget.customerId);
    final pays = await _db.getPartyPayments(widget.customerId, limit: 500);
    final inv = await _db.getInvoices(
        customerId: widget.customerId, from: _historyStart, to: DateTime.now());

    List<Map<String, dynamic>> pur = [];
    if (row != null &&
        (row['party_type'] as String? ?? 'customer') ==
            CustomerModel.typeSupplier) {
      pur = await _db.getPurchases(
          supplierId: widget.customerId,
          from: _historyStart,
          to: DateTime.now());
      pur = await Future.wait(pur.map((purchase) async {
        final id = purchase['id'] as int?;
        if (id == null) return purchase;
        final full = await _db.getPurchaseById(id);
        if (full == null) return purchase;
        return {...purchase, 'items': full['items'] ?? const []};
      }));
    }
    if (!mounted) return;
    setState(() {
      _customer = row != null ? CustomerModel.fromMap(row) : null;
      _payments = pays;
      _invoices = inv;
      _purchases = pur;
      _loading = false;
    });
  }

  // ── Build ledger (newest first for display) ──────────────────────────────
  List<Map<String, dynamic>> _buildLedger(CustomerModel c) {
    final rows = <Map<String, dynamic>>[];

    if (!c.isSupplier) {
      for (final inv in _invoices) {
        final total = (inv['total'] as num?)?.toDouble() ?? 0;
        final paid = (inv['paid'] as num?)?.toDouble() ?? 0;
        final due = (inv['balance'] as num?)?.toDouble() ?? (total - paid);
        rows.add({
          'kind': 'sale',
          'date': inv['created_at'] as String? ?? '',
          'ref': inv['invoice_no'] as String? ?? '',
          'invoiceId': inv['id'] as int?,
          'summary': inv['items_summary'] as String? ?? '',
          'total': total,
          'paid': paid,
          'due': due,
          'paymentMethod': inv['payment_method'] as String? ?? '',
        });
      }
    } else {
      for (final pr in _purchases) {
        final total = (pr['total'] as num?)?.toDouble() ?? 0;
        final paid = (pr['paid'] as num?)?.toDouble() ?? 0;
        final due = (pr['balance'] as num?)?.toDouble() ?? (total - paid);
        rows.add({
          'kind': 'purchase',
          'date': pr['created_at'] as String? ?? '',
          'ref': pr['purchase_no'] as String? ?? '',
          'purchaseId': pr['id'] as int?,
          'summary': pr['items_summary'] as String? ?? '',
          'items': (pr['items'] as List?) ?? const [],
          'notes': pr['notes'] as String? ?? '',
          'total': total,
          'paid': paid,
          'due': due,
          'paymentMethod': pr['payment_method'] as String? ?? '',
        });
      }
    }

    for (final p in _payments) {
      final method = p['payment_method'] as String? ?? '';
      final notes = p['notes'] as String? ?? '';
      rows.add({
        'kind': 'payment',
        'paymentId': p['id'] as int?,
        'date': p['created_at'] as String? ?? '',
        'ref': notes.isEmpty ? method : '$method · $notes',
        'paymentMethod': method,
        'notes': notes,
        'paymentAmount': (p['amount'] as num?)?.toDouble() ?? 0,
      });
    }

    // Sort chronologically (oldest first)
    rows.sort((a, b) {
      final da =
          DateTime.tryParse(a['date'] as String? ?? '') ?? DateTime(1970);
      final db =
          DateTime.tryParse(b['date'] as String? ?? '') ?? DateTime(1970);
      return da.compareTo(db);
    });

    // ── Running balance calculation ──
    // Start from 0. Bills add their unpaid due. Payments reduce the balance.
    // This mirrors how the DB tracks balance:
    //   insertInvoice/insertPurchase: balance += bill.balance (unpaid portion)
    //   insertPartyPayment:           balance -= payment.amount
    double running = 0;
    for (final r in rows) {
      if (r['kind'] == 'payment') {
        running -= (r['paymentAmount'] as num?)?.toDouble() ?? 0;
      } else {
        running += (r['due'] as num?)?.toDouble() ?? 0;
      }
      r['runningBalance'] = running;
    }

    // Newest first for display
    return rows.reversed.toList();
  }

  // ── Chronological order for PDF ─────────────────────────────────────────
  List<Map<String, dynamic>> _buildLedgerChronological(CustomerModel c) {
    return _buildLedger(c).reversed.toList();
  }

  Map<String, double> _cashCreditSummary(List<Map<String, dynamic>> ledger) {
    double cashSales = 0, creditSales = 0, cashPayments = 0, upiPayments = 0;
    for (final r in ledger) {
      if (r['kind'] == 'payment') {
        final amt = (r['paymentAmount'] as num?)?.toDouble() ?? 0;
        final method = (r['paymentMethod'] as String? ?? '').toLowerCase();
        if (method == 'upi') {
          upiPayments += amt;
        } else {
          cashPayments += amt;
        }
      } else {
        final method = (r['paymentMethod'] as String? ?? '').toLowerCase();
        final total = (r['total'] as num?)?.toDouble() ?? 0;
        if (method == 'credit') {
          creditSales += total;
        } else {
          cashSales += total;
        }
      }
    }
    return {
      'cashSales': cashSales,
      'creditSales': creditSales,
      'cashPayments': cashPayments,
      'upiPayments': upiPayments,
    };
  }

  String _statusLabel(double due, double paid, double total) {
    if (due <= 0.009) return 'Paid';
    if (paid > 0.009) return 'Partial';
    return 'Unpaid';
  }

  double _ledgerClosingBalance(CustomerModel c) {
    final chronological = _buildLedger(c).reversed.toList();
    if (chronological.isEmpty) return c.balance;
    return (chronological.last['runningBalance'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> _fixPartyBalance(CustomerModel c) async {
    final sym = context.read<SettingsProvider>().currencySymbol;
    final correctBalance = _ledgerClosingBalance(c);
    final diff = (c.balance - correctBalance).abs();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fix party balance?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current balance: $sym${c.balance.toStringAsFixed(2)}'),
            const SizedBox(height: 6),
            Text('Correct balance: $sym${correctBalance.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            Text(diff <= 0.01
                ? 'This party balance is already correct.'
                : 'This will update the party balance from the ledger entries.'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: diff <= 0.01 ? null : () => Navigator.pop(ctx, true),
              child: const Text('Fix Now')),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    await _db.updateCustomerBalance(widget.customerId, correctBalance);
    if (!mounted) return;
    await context.read<CustomerProvider>().loadCustomers();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Balance fixed to $sym${correctBalance.toStringAsFixed(2)}')));
    }
  }

  Future<void> _exportCsv(CustomerModel c) async {
    final sym = context.read<SettingsProvider>().currencySymbol;
    final ledger = _buildLedger(c);
    final csv = PartyAccountExport.buildPartyStatementCsv(
      partyName: c.name,
      partyType: c.isSupplier ? 'supplier' : 'customer',
      currencySymbol: sym,
      closingBalance: c.balance,
      ledgerRows: ledger,
    );
    await PartyAccountExport.shareCsv('party_${c.id}_${c.name}.csv', csv);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('CSV ready to share')));
    }
  }

  Future<_StatementPdfOptions?> _askPdfOptions(CustomerModel c) async {
    final defaultName =
        '${c.name}_${DateFormat('dd-MM-yyyy').format(DateTime.now())}';
    return showModalBottomSheet<_StatementPdfOptions>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StatementPdfOptionsSheet(defaultName: defaultName),
    );
  }

  Future<void> _exportPdf(CustomerModel c) async {
    final settings = context.read<SettingsProvider>();
    final options = await _askPdfOptions(c);
    if (options == null) return;

    final chronoLedger = _buildLedgerChronological(c);

    final now = DateTime.now();
    final firstDate = chronoLedger.isNotEmpty
        ? (DateTime.tryParse(chronoLedger.first['date'] as String? ?? '') ??
            now)
        : DateTime(now.year, now.month, 1);
    final fromDate = DateFormat('yyyy-MM-dd').format(firstDate);
    final toDate = DateFormat('yyyy-MM-dd').format(now);

    final exportRows = chronoLedger.map((r) {
      final kind = r['kind'] as String? ?? '';
      if (kind == 'payment') {
        return <String, dynamic>{
          'kind': 'payment',
          'date': r['date'],
          'ref': r['ref'] ?? '',
          'status': 'Paid',
          'paymentAmount': r['paymentAmount'] ?? 0.0,
          'paymentMode': r['paymentMethod'] ?? '',
        };
      } else {
        final total = (r['total'] as num?)?.toDouble() ?? 0;
        final paid = (r['paid'] as num?)?.toDouble() ?? 0;
        final due = (r['due'] as num?)?.toDouble() ?? (total - paid);
        return <String, dynamic>{
          'kind': kind,
          'date': r['date'],
          'ref': r['ref'] ?? '',
          'status': _statusLabel(due, paid, total),
          'total': total,
          'paid': paid,
          'notes': r['notes'] ?? '',
          'items': r['items'] ?? const [],
        };
      }
    }).toList();

    pw.ImageProvider? logo;
    try {
      final bytes = await rootBundle.load('assets/images/log.png');
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      logo = null;
    }

    await PartyAccountExport.sharePartyStatementPdf(
      shopName: settings.shopName,
      shopPhone: settings.shopPhone,
      shopEmail: settings.shopEmail,
      shopAddress: settings.shopAddress,
      partyName: c.name,
      partyPhone: c.phone ?? '',
      partyType: c.isSupplier ? 'supplier' : 'customer',
      currencySymbol: settings.currencySymbol,
      openingReceivable: 0,
      openingPayable: 0,
      fromDate: fromDate,
      toDate: toDate,
      ledgerRows: exportRows,
      shopLogoImage: logo,
      showItemDetails: options.itemDetails,
      showDescription: options.description,
      showPaymentStatus: options.paymentStatus,
      showPaymentInformation: options.paymentInformation,
      fileName: options.fileName,
      // Pass the actual closing balance from the DB (source of truth)
      closingBalance: c.balance,
    );

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('PDF ready to share')));
    }
  }

  Future<void> _printThermal(CustomerModel c) async {
    final settings = context.read<SettingsProvider>();
    final ledger = _buildLedger(c);
    final err = await ThermalInvoicePrinter.printPartyAccount(
      settings: settings,
      partyName: c.name,
      partyPhone: c.phone,
      isSupplier: c.isSupplier,
      closingBalance: c.balance,
      ledgerRows: ledger.map((r) {
        if (r['kind'] == 'payment') {
          return {
            'kind': 'payment',
            'date': r['date'],
            'line': r['ref'] as String? ?? 'Payment',
            'amount': r['paymentAmount'],
          };
        }
        return {
          'kind': r['kind'],
          'date': r['date'],
          'line':
              '${r['kind'] == 'purchase' ? 'Purchase' : 'Sale'} ${r['ref']}',
          'amount': r['total'],
          'paid': r['paid'],
          'due': r['due'],
        };
      }).toList(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(err ?? 'Sent to printer')));
  }

  Future<void> _paymentDialog({Map<String, dynamic>? payment}) async {
    final c = _customer;
    if (c == null) return;
    final editing = payment != null;
    final amtCtrl = TextEditingController(
        text: editing
            ? ((payment['paymentAmount'] as num?)?.toDouble() ?? 0)
                .toStringAsFixed(0)
            : '');
    final noteCtrl =
        TextEditingController(text: payment?['notes']?.toString() ?? '');
    String method = payment?['paymentMethod']?.toString() ?? 'Cash';
    final sym = context.read<SettingsProvider>().currencySymbol;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(builder: (ctx, setLocal) {
          return Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.payments_outlined,
                        color: Colors.green.shade700, size: 20)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                      editing
                          ? 'Edit Payment'
                          : c.isSupplier
                              ? 'Pay Supplier'
                              : 'Take Payment',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  Text('Balance: $sym${c.balance.toStringAsFixed(0)}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ]),
              ]),
              const SizedBox(height: 20),
              TextField(
                controller: amtCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '$sym ',
                    prefixStyle:
                        const TextStyle(fontSize: 20, color: Colors.grey),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.green, width: 2))),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Text('Method:',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(width: 10),
                ...['Cash', 'UPI', 'Card'].map((m) {
                  final sel = m == method;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setLocal(() => method = m),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                            color: sel
                                ? Colors.green.shade600
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: sel
                                    ? Colors.green.shade600
                                    : Colors.grey.shade300)),
                        child: Text(m,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color:
                                    sel ? Colors.white : Colors.grey.shade700)),
                      ),
                    ),
                  );
                }),
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: noteCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: const Icon(Icons.note_outlined, size: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      icon: const Icon(Icons.check_circle_outline_rounded,
                          size: 18),
                      label: Text(editing ? 'Update Payment' : 'Save Payment',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800)))),
            ]),
          );
        }),
      ),
    );

    if (ok != true || !mounted) return;
    final amount = double.tryParse(amtCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    try {
      if (editing) {
        final id = payment['paymentId'] as int?;
        if (id == null) throw StateError('Payment id missing');
        await _db.updatePartyPayment(
          paymentId: id,
          customerId: widget.customerId,
          amount: amount,
          paymentMethod: method,
          notes: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        );
      } else {
        await _db.insertPartyPayment(
          customerId: widget.customerId,
          amount: amount,
          paymentMethod: method,
          notes: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return;
    }
    if (!mounted) return;
    await context.read<CustomerProvider>().loadCustomers();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white),
          SizedBox(width: 8),
          Text('Payment saved'),
        ]),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Future<void> _deletePayment(Map<String, dynamic> payment) async {
    final id = payment['paymentId'] as int?;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete payment?'),
        content: const Text(
            'This will remove the payment and recalculate the party balance.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _db.deletePartyPayment(paymentId: id, customerId: widget.customerId);
    if (!mounted) return;
    await context.read<CustomerProvider>().loadCustomers();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Payment deleted')));
    }
  }

  Future<void> _goToNewSale() async {
    final c = _customer;
    if (c == null || !mounted) return;
    context.read<BillingProvider>().clear();
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => NewBillScreen(preselectedCustomer: c)));
    if (mounted) await _load();
  }

  Future<void> _goToNewPurchase() async {
    final c = _customer;
    if (c == null || !mounted) return;
    context.read<PurchaseProvider>().clear();
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PurchaseScreen(initialSupplier: c)));
    if (!mounted) return;
    await context.read<CustomerProvider>().loadCustomers();
    await context.read<InventoryProvider>().loadItems();
    await _load();
  }

  Future<void> _openPurchaseBill(int id) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => PurchaseScreen(editingPurchaseId: id)));
    if (!mounted) return;
    if (changed == true) {
      await context.read<CustomerProvider>().loadCustomers();
      await context.read<InventoryProvider>().loadItems();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sym = context.watch<SettingsProvider>().currencySymbol;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final c = _customer;
    if (c == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Party')),
          body: const Center(child: Text('Party not found')));
    }

    final ledger = _buildLedger(c);
    final summary = _cashCreditSummary(ledger);
    final dateFmt = DateFormat('dd/MM/yy');
    final timeFmt = DateFormat('hh:mm a');

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(c.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
              tooltip: 'Fix Balance',
              icon: const Icon(Icons.build_circle_outlined),
              onPressed: () => _fixPartyBalance(c)),
          IconButton(
              tooltip: 'Download CSV',
              icon: const Icon(Icons.download_outlined),
              onPressed: () => _exportCsv(c)),
          IconButton(
              tooltip: 'Download PDF',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () => _exportPdf(c)),
          IconButton(
              tooltip: 'Print',
              icon: const Icon(Icons.print_outlined),
              onPressed: () => _printThermal(c)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 10,
                  offset: const Offset(0, -2))
            ],
          ),
          child: Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _paymentDialog,
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: Text(c.isSupplier ? 'Pay Supplier' : 'Take Payment',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: c.isSupplier ? _goToNewPurchase : _goToNewSale,
                style: FilledButton.styleFrom(
                    backgroundColor: _red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                icon: Icon(
                    c.isSupplier
                        ? Icons.add_shopping_cart_rounded
                        : Icons.receipt_long_outlined,
                    size: 18),
                label: Text(c.isSupplier ? 'Add Purchase' : 'Add Sale',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
        ),
      ),
      body: RefreshIndicator(
        color: _red,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _PartyInfoCard(c: c, sym: sym),
            const SizedBox(height: 10),
            _CashCreditCard(summary: summary, sym: sym),
            const SizedBox(height: 14),
            Row(children: [
              const Text('Account Statement',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${ledger.length} entries',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ]),
            const SizedBox(height: 10),
            if (ledger.isNotEmpty) ...[
              _ClosingBalancePill(balance: c.balance, sym: sym),
              const SizedBox(height: 10),
            ],
            if (ledger.isEmpty)
              _EmptyLedger()
            else
              ...ledger.map((r) => _LedgerRow(
                    row: r,
                    dateFmt: dateFmt,
                    timeFmt: timeFmt,
                    sym: sym,
                    isSupplier: c.isSupplier,
                    onOpenSaleBill: (id) => showInvoiceDetailSheet(context, id),
                    onOpenPurchaseBill: _openPurchaseBill,
                    onEditPayment: (row) => _paymentDialog(payment: row),
                    onDeletePayment: _deletePayment,
                  )),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ── PARTY INFO CARD ──────────────────────────────────────────────────────────
class _PartyInfoCard extends StatelessWidget {
  final CustomerModel c;
  final String sym;
  static const _red = Color(0xFFE31E24);
  const _PartyInfoCard({required this.c, required this.sym});

  @override
  Widget build(BuildContext context) {
    final isPositive = c.balance > 0.01;
    final balColor = isPositive
        ? (c.isSupplier ? Colors.indigo : const Color(0xFFE65100))
        : Colors.green.shade700;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
              color: c.isSupplier
                  ? Colors.indigo.withOpacity(0.07)
                  : const Color(0xFFFDE8E8),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12))),
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: c.isSupplier ? Colors.indigo : _red,
                    shape: BoxShape.circle),
                child: Center(
                    child: Text(
                        c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: c.isSupplier ? Colors.indigo : _red,
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(c.isSupplier ? 'Supplier' : 'Customer',
                            style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white))),
                    if ((c.phone ?? '').isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.phone_outlined,
                          size: 11, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Text(c.phone!,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ]),
                ])),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      c.isSupplier
                          ? 'You Owe (Payable)'
                          : 'They Owe (Receivable)',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 4),
                  FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('$sym${c.balance.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: balColor))),
                ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color:
                      isPositive ? Colors.orange.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isPositive
                          ? Colors.orange.shade200
                          : Colors.green.shade200)),
              child: Column(children: [
                Icon(
                    isPositive
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline,
                    color: isPositive ? Colors.orange : Colors.green,
                    size: 22),
                const SizedBox(height: 3),
                Text(isPositive ? 'Due' : 'Clear',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isPositive ? Colors.orange : Colors.green)),
              ]),
            ),
          ]),
        ),
        if ((c.address ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              Icon(Icons.location_on_outlined,
                  size: 13, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Flexible(
                  child: Text(c.address!,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500))),
            ]),
          ),
      ]),
    );
  }
}

// ── CASH & CREDIT CARD ───────────────────────────────────────────────────────
class _CashCreditCard extends StatelessWidget {
  final Map<String, double> summary;
  final String sym;
  const _CashCreditCard({required this.summary, required this.sym});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Cash & Credit Summary',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _SumBox(
                  label: 'Cash Sales',
                  value:
                      '$sym${(summary['cashSales'] ?? 0).toStringAsFixed(0)}',
                  color: Colors.green.shade700,
                  icon: Icons.payments_outlined)),
          const SizedBox(width: 8),
          Expanded(
              child: _SumBox(
                  label: 'Credit Sales',
                  value:
                      '$sym${(summary['creditSales'] ?? 0).toStringAsFixed(0)}',
                  color: Colors.orange.shade700,
                  icon: Icons.credit_card_outlined)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: _SumBox(
                  label: 'Cash Received',
                  value:
                      '$sym${(summary['cashPayments'] ?? 0).toStringAsFixed(0)}',
                  color: Colors.blue.shade700,
                  icon: Icons.account_balance_wallet_outlined)),
          const SizedBox(width: 8),
          Expanded(
              child: _SumBox(
                  label: 'UPI Received',
                  value:
                      '$sym${(summary['upiPayments'] ?? 0).toStringAsFixed(0)}',
                  color: Colors.purple.shade700,
                  icon: Icons.qr_code_outlined)),
        ]),
      ]),
    );
  }
}

class _SumBox extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _SumBox(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.15))),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}

// ── CLOSING BALANCE PILL ─────────────────────────────────────────────────────
class _ClosingBalancePill extends StatelessWidget {
  final double balance;
  final String sym;
  const _ClosingBalancePill({required this.balance, required this.sym});

  @override
  Widget build(BuildContext context) {
    final isDue = balance > 0.01;
    final color = isDue ? Colors.orange.shade700 : Colors.green.shade700;
    final bgColor = isDue ? Colors.orange.shade50 : Colors.green.shade50;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Row(children: [
        Icon(isDue ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            color: color, size: 18),
        const SizedBox(width: 10),
        Text(isDue ? 'CLOSING BALANCE DUE' : 'ACCOUNT CLEAR',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.5)),
        const Spacer(),
        Text('$sym${balance.abs().toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, color: color)),
      ]),
    );
  }
}

// ── LEDGER ROW ───────────────────────────────────────────────────────────────
class _LedgerRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final DateFormat dateFmt, timeFmt;
  final String sym;
  final bool isSupplier;
  final void Function(int id) onOpenSaleBill;
  final void Function(int id) onOpenPurchaseBill;
  final void Function(Map<String, dynamic> row) onEditPayment;
  final void Function(Map<String, dynamic> row) onDeletePayment;

  const _LedgerRow(
      {required this.row,
      required this.dateFmt,
      required this.timeFmt,
      required this.sym,
      required this.isSupplier,
      required this.onOpenSaleBill,
      required this.onOpenPurchaseBill,
      required this.onEditPayment,
      required this.onDeletePayment});

  @override
  Widget build(BuildContext context) {
    final kind = row['kind'] as String? ?? '';
    final dt = DateTime.tryParse(row['date'] as String? ?? '');
    final dateStr = dt != null ? dateFmt.format(dt) : '';
    final timeStr = dt != null ? timeFmt.format(dt) : '';
    final runBal = (row['runningBalance'] as num?)?.toDouble() ?? 0;

    if (kind == 'payment') {
      final amt = (row['paymentAmount'] as num?)?.toDouble() ?? 0;
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade100)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(children: [
            Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: Colors.green.shade100, shape: BoxShape.circle),
                child: const Icon(Icons.payments_outlined,
                    color: Colors.green, size: 17)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(isSupplier ? 'You paid' : 'Payment received',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  Text('${row['ref'] ?? ''}  ·  $dateStr  $timeStr',
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('- $sym${amt.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.green.shade700)),
              const SizedBox(height: 2),
              Text('Bal: $sym${runBal.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: runBal > 0.01
                          ? Colors.orange.shade700
                          : Colors.green.shade700)),
            ]),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon:
                  Icon(Icons.more_vert, size: 18, color: Colors.grey.shade600),
              onSelected: (value) {
                if (value == 'edit') onEditPayment(row);
                if (value == 'delete') onDeletePayment(row);
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ]),
        ),
      );
    }

    final ref = row['ref'] as String? ?? '';
    final total = (row['total'] as num?)?.toDouble() ?? 0;
    final paid = (row['paid'] as num?)?.toDouble() ?? 0;
    final due = (row['due'] as num?)?.toDouble() ?? 0;
    final isSale = kind == 'sale';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color:
                  due > 0.01 ? Colors.orange.shade100 : Colors.grey.shade100)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: isSale ? Colors.blue.shade50 : Colors.purple.shade50,
                    shape: BoxShape.circle),
                child: Icon(
                    isSale
                        ? Icons.receipt_long_rounded
                        : Icons.shopping_bag_outlined,
                    size: 15,
                    color: isSale
                        ? Colors.blue.shade600
                        : Colors.purple.shade600)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('${isSale ? 'Sale' : 'Purchase'}  #$ref',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  Text('$dateStr  $timeStr',
                      style:
                          TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                  color: runBal > 0.01
                      ? Colors.orange.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: runBal > 0.01
                          ? Colors.orange.shade200
                          : Colors.green.shade200)),
              child: Column(children: [
                Text('Balance',
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: runBal > 0.01
                            ? Colors.orange.shade700
                            : Colors.green.shade700)),
                Text('$sym${runBal.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: runBal > 0.01
                            ? Colors.orange.shade700
                            : Colors.green.shade700)),
              ]),
            ),
          ]),
          if ((row['summary'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
                padding: const EdgeInsets.only(left: 42),
                child: Text(row['summary'],
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue.shade700,
                        fontStyle: FontStyle.italic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
          ],
          const SizedBox(height: 10),
          Row(children: [
            _InfoChip(label: 'Bill', value: '$sym${total.toStringAsFixed(0)}'),
            const SizedBox(width: 6),
            _InfoChip(label: 'Paid', value: '$sym${paid.toStringAsFixed(0)}'),
            const SizedBox(width: 6),
            _InfoChip(
                label: 'Due',
                value: '$sym${due.toStringAsFixed(0)}',
                highlight: due > 0.01),
            const Spacer(),
            if (ref.isNotEmpty)
              GestureDetector(
                  onTap: () {
                    final id = isSale
                        ? row['invoiceId'] as int?
                        : row['purchaseId'] as int?;
                    if (id == null) return;
                    if (isSale) {
                      onOpenSaleBill(id);
                    } else {
                      onOpenPurchaseBill(id);
                    }
                  },
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(isSale ? 'View Bill' : 'View / Edit Bill',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.blue.shade700)))),
          ]),
        ]),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label, value;
  final bool highlight;
  const _InfoChip(
      {required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
          color: highlight ? Colors.orange.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color:
                  highlight ? Colors.orange.shade200 : Colors.grey.shade200)),
      child: Column(children: [
        Text(label,
            style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: highlight ? Colors.orange.shade700 : Colors.black87)),
      ]),
    );
  }
}

// ── EMPTY LEDGER ─────────────────────────────────────────────────────────────
class _EmptyLedger extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100)),
      child: Column(children: [
        Icon(Icons.receipt_long_outlined,
            size: 44, color: Colors.grey.shade300),
        const SizedBox(height: 10),
        Text('No bills or payments yet',
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text('Use "Add Sale" below to create a bill',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
      ]),
    );
  }
}

// ── PDF OPTIONS ──────────────────────────────────────────────────────────────
class _StatementPdfOptions {
  final String fileName;
  final bool itemDetails, description, paymentStatus, paymentInformation;
  const _StatementPdfOptions({
    required this.fileName,
    required this.itemDetails,
    required this.description,
    required this.paymentStatus,
    required this.paymentInformation,
  });
}

class _StatementPdfOptionsSheet extends StatefulWidget {
  final String defaultName;
  const _StatementPdfOptionsSheet({required this.defaultName});
  @override
  State<_StatementPdfOptionsSheet> createState() =>
      _StatementPdfOptionsSheetState();
}

class _StatementPdfOptionsSheetState extends State<_StatementPdfOptionsSheet> {
  late final TextEditingController _nameCtrl;
  bool _itemDetails = false,
      _description = false,
      _paymentStatus = false,
      _paymentInformation = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.defaultName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final name = _nameCtrl.text.trim().isEmpty
        ? widget.defaultName
        : _nameCtrl.text.trim();
    Navigator.pop(
        context,
        _StatementPdfOptions(
          fileName: name,
          itemDetails: _itemDetails,
          description: _description,
          paymentStatus: _paymentStatus,
          paymentInformation: _paymentInformation,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                  child: Row(children: [
                    const Expanded(
                        child: Text('What to display on PDF?',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800))),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded)),
                  ])),
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'PDF name',
                          isDense: true,
                          border: InputBorder.none),
                      style: const TextStyle(fontSize: 13))),
              const Divider(height: 1),
              _PdfOptionTile(
                  label: 'Item Details',
                  value: _itemDetails,
                  onChanged: (v) => setState(() => _itemDetails = v)),
              _PdfOptionTile(
                  label: 'Description',
                  value: _description,
                  onChanged: (v) => setState(() => _description = v)),
              _PdfOptionTile(
                  label: 'Payment status',
                  value: _paymentStatus,
                  onChanged: (v) => setState(() => _paymentStatus = v)),
              _PdfOptionTile(
                  label: 'Payment Information',
                  value: _paymentInformation,
                  onChanged: (v) => setState(() => _paymentInformation = v)),
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                  child: Row(children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22)),
                                side: BorderSide(color: Colors.grey.shade200),
                                backgroundColor: Colors.grey.shade50),
                            child: const Text('Cancel',
                                style:
                                    TextStyle(fontWeight: FontWeight.w800)))),
                    const SizedBox(width: 16),
                    Expanded(
                        child: FilledButton(
                            onPressed: _apply,
                            style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE31E24),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22))),
                            child: const Text('Apply',
                                style:
                                    TextStyle(fontWeight: FontWeight.w800)))),
                  ])),
            ])),
      ),
    );
  }
}

class _PdfOptionTile extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _PdfOptionTile(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600))),
              Checkbox(
                  value: value,
                  onChanged: (v) => onChanged(v ?? false),
                  activeColor: Colors.blue.shade600),
            ])));
  }
}
