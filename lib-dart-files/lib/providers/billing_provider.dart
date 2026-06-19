import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/customer_model.dart';
import '../providers/settings_provider.dart';
import '../services/firebase_sync_service.dart';

class BillLine {
  final int? itemId;
  final String itemName;
  double qty;
  final String unit;
  double price;

  BillLine({
    this.itemId,
    required this.itemName,
    required this.qty,
    required this.unit,
    required this.price,
  });

  double get amount => qty * price;

  Map<String, dynamic> toMap() => {
        'item_id'  : itemId,
        'item_name': itemName,
        'quantity' : qty,
        'unit'     : unit,
        'price'    : price,
        'amount'   : amount,
      };
}

class BillingProvider extends ChangeNotifier {
  final _db   = DatabaseHelper.instance;
  final _sync = FirebaseSyncService.instance;

  final List<BillLine> _lines = [];
  CustomerModel? _customer;
  int?    _editingInvoiceId;
  String? _editingInvoiceNo;
  Map<String, dynamic>? _editingInvoice;

  double _shipping  = 0;
  double _packaging = 0;
  int?   _deliveryBoyId;
  String? _deliveryBoyName;

  List<BillLine> get lines             => List.unmodifiable(_lines);
  CustomerModel? get customer          => _customer;
  int?           get editingInvoiceId  => _editingInvoiceId;
  String?        get editingInvoiceNo  => _editingInvoiceNo;
  bool           get isEditing         => _editingInvoiceId != null;
  double         get shipping          => _shipping;
  double         get packaging         => _packaging;
  int?           get deliveryBoyId     => _deliveryBoyId;
  String?        get deliveryBoyName   => _deliveryBoyName;

  double subtotal() => _lines.fold(0, (s, l) => s + l.amount);

  double taxAmount(SettingsProvider s, double base) =>
      s.taxEnabled ? base * s.taxPercent / 100 : 0;

  double totalAfterDiscountAndTax(
    SettingsProvider s,
    double discount, {
    double shipping  = 0,
    double packaging = 0,
  }) {
    final sub       = subtotal();
    final afterDisc = (sub - discount).clamp(0.0, double.infinity);
    final tax       = taxAmount(s, afterDisc);
    return afterDisc + tax + shipping + packaging;
  }

  double totalAfter(SettingsProvider s, double discount) =>
      totalAfterDiscountAndTax(s, discount);

  void addManualItem({
    int?    itemId,
    required String itemName,
    required double qty,
    required String unit,
    required double price,
  }) {
    final idx = itemId != null
        ? _lines.indexWhere((l) => l.itemId == itemId)
        : -1;
    if (idx >= 0) {
      _lines[idx].qty += qty;
    } else {
      _lines.add(BillLine(
          itemId  : itemId,
          itemName: itemName,
          qty     : qty,
          unit    : unit,
          price   : price));
    }
    notifyListeners();
  }

  void addItem({
    int?    itemId,
    required String itemName,
    required double qty,
    required String unit,
    required double price,
  }) =>
      addManualItem(
          itemId  : itemId,
          itemName: itemName,
          qty     : qty,
          unit    : unit,
          price   : price);

  void updateLine(int index, {double? qty, double? price}) {
    if (index < 0 || index >= _lines.length) return;
    if (qty != null) {
      if (qty <= 0) {
        _lines.removeAt(index);
      } else {
        _lines[index].qty = qty;
      }
    }
    if (price != null) _lines[index].price = price;
    notifyListeners();
  }

  void removeLine(int index) {
    if (index >= 0 && index < _lines.length) {
      _lines.removeAt(index);
      notifyListeners();
    }
  }

  void setQty(int index, double qty) {
    if (qty <= 0) {
      _lines.removeAt(index);
    } else {
      _lines[index].qty = qty;
    }
    notifyListeners();
  }

  void setPrice(int index, double price) {
    _lines[index].price = price;
    notifyListeners();
  }

  void removeAt(int index) {
    _lines.removeAt(index);
    notifyListeners();
  }

  void setCustomer(CustomerModel? c) {
    _customer = c;
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    _customer         = null;
    _editingInvoiceId = null;
    _editingInvoiceNo = null;
    _editingInvoice   = null;
    _shipping         = 0;
    _packaging        = 0;
    _deliveryBoyId    = null;
    _deliveryBoyName  = null;
    notifyListeners();
  }

  void setDeliveryBoy(int? id, String? name) {
    _deliveryBoyId = id;
    _deliveryBoyName = name;
    notifyListeners();
  }

  void startEditing(Map<String, dynamic> invoice) {
    _editingInvoiceId = invoice['id']         as int?;
    _editingInvoiceNo = invoice['invoice_no'] as String?;
    _editingInvoice   = invoice;
    _shipping         = (invoice['shipping']  as num?)?.toDouble() ?? 0;
    _packaging        = (invoice['packaging'] as num?)?.toDouble() ?? 0;
    _deliveryBoyId    = invoice['delivery_boy_id'] as int?;
    _deliveryBoyName  = invoice['delivery_boy_name'] as String?;
    _lines.clear();
    final items = invoice['items'] as List? ?? [];
    for (final item in items) {
      _lines.add(BillLine(
        itemId  : item['item_id']  as int?,
        itemName: item['item_name'] as String? ?? '',
        qty     : (item['quantity'] as num?)?.toDouble() ?? 1,
        unit    : item['unit']     as String? ?? 'Kg',
        price   : (item['price']   as num?)?.toDouble() ?? 0,
      ));
    }
    notifyListeners();
  }

  Future<String> _generateUniqueInvoiceNo(String prefix) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      "SELECT invoice_no FROM invoices WHERE invoice_no LIKE ? ORDER BY invoice_no DESC LIMIT 100",
      ['$prefix%'],
    );
    final usedNums = <int>{};
    for (final row in rows) {
      final no     = row['invoice_no'] as String? ?? '';
      final suffix = no.replaceFirst(prefix, '');
      final n      = int.tryParse(suffix);
      if (n != null) usedNums.add(n);
    }
    var candidate = 1;
    while (usedNums.contains(candidate)) {
      candidate++;
    }
    while (true) {
      final no       = '$prefix${candidate.toString().padLeft(4, '0')}';
      final existing = await db.rawQuery(
        'SELECT id FROM invoices WHERE invoice_no = ? LIMIT 1',
        [no],
      );
      if (existing.isEmpty) return no;
      candidate++;
    }
  }

  // ── Save Bill ──────────────────────────────────────────────────────────────
  Future<String?> saveBill({
    required SettingsProvider settings,
    required double discount,
    required double paid,
    required String paymentMethod,
    String? notes,
    double  shipping  = 0,
    double  packaging = 0,
    String? invoiceDate,
  }) async {
    if (_lines.isEmpty) return 'Add at least one item';

    final now     = DateTime.now().toIso8601String();
    final sub     = subtotal();
    final disc    = discount.clamp(0.0, sub);
    final base    = (sub - disc).clamp(0.0, double.infinity);
    final tax     = taxAmount(settings, base);
    final total   = base + tax + shipping + packaging;

    // Unpaid portion of THIS bill only
    final billBalance = (total - paid).clamp(0.0, double.infinity);

    final status = billBalance <= 0
        ? 'paid'
        : paid > 0
            ? 'partial'
            : 'unpaid';

    // ── FIX: Correct previous/current balance calculation ──────────────────
    //
    // NEW invoice:
    //   prevBal = customer.balance  (what they already owe)
    //   curBal  = prevBal + billBalance
    //
    // EDIT existing invoice:
    //   customer.balance already includes the OLD bill's unpaid balance.
    //   We must undo the old bill first, then add the new one.
    //   prevBal = customer.balance - oldBillBalance
    //   curBal  = prevBal + billBalance
    // ──────────────────────────────────────────────────────────────────────
    double prevBal;
    double curBal;

    if (_editingInvoiceId != null) {
      // Editing: undo old bill's unpaid balance from customer balance
      final oldBillBalance =
          (_editingInvoice?['balance'] as num?)?.toDouble() ?? 0.0;
      prevBal = (_customer?.balance ?? 0.0) - oldBillBalance;
      curBal  = prevBal + billBalance;
    } else {
      // New invoice
      prevBal = _customer?.balance ?? 0.0;
      curBal  = prevBal + billBalance;
    }

    // Safety: curBal should never go below 0
    if (curBal < 0) curBal = 0;

    final prefix    = settings.invoicePrefix.isNotEmpty
        ? settings.invoicePrefix
        : 'INV';
    final invoiceNo = _editingInvoiceId != null
        ? (_editingInvoice?['invoice_no'] as String? ??
            await _generateUniqueInvoiceNo(prefix))
        : await _generateUniqueInvoiceNo(prefix);

    final invoice = {
      'invoice_no'      : invoiceNo,
      'customer_id'     : _customer?.id,
      'customer_name'   : _customer?.name ?? 'Walk-in Customer',
      'customer_phone'  : _customer?.phone ?? '',
      'subtotal'        : sub,
      'discount'        : disc,
      'tax'             : tax,
      'shipping':        shipping,
      'packaging':       packaging,
      'delivery_boy_id': _deliveryBoyId,
      'delivery_boy_name': _deliveryBoyName ?? '',
      'total':           total,
      'paid'            : paid,
      'balance'         : billBalance,
      'previous_balance': prevBal,
      'current_balance' : curBal,
      'payment_method'  : paymentMethod,
      'status'          : status,
      'notes'           : notes ?? '',
      'invoice_date'    : invoiceDate ?? now,
      'store_id'        : settings.currentStoreId,
      'created_at'      : now,
      'updated_at'      : now,
    };

    final items = _lines.map((l) => l.toMap()).toList();

    try {
      int invoiceId;
      if (_editingInvoiceId != null) {
        await _db.updateInvoice(
            invoiceId: _editingInvoiceId!,
            invoice  : invoice,
            items    : items);
        invoiceId = _editingInvoiceId!;
      } else {
        invoiceId = await _db.insertInvoice(invoice, items);
      }

      await _sync.pushInvoice(invoiceId);
      if (_customer != null && _customer!.id != null) {
        final updatedCustomer =
            await _db.getCustomerById(_customer!.id!);
        if (updatedCustomer != null) {
          await _sync.pushCustomer(updatedCustomer);
        }
      }

      clear();
      return null;
    } catch (e) {
      debugPrint('❌ saveBill error: $e');
      return e.toString();
    }
  }
}