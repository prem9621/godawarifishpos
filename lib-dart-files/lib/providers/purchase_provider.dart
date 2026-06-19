import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/customer_model.dart';
import '../providers/inventory_provider.dart';
import '../providers/settings_provider.dart';
import '../services/firebase_sync_service.dart';

class PurchaseLine {
  final int?   itemId;
  final String itemName;
  double       qty;
  final String unit;
  double       price;

  PurchaseLine({
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

class PurchaseProvider extends ChangeNotifier {
  final _db   = DatabaseHelper.instance;
  final _sync = FirebaseSyncService.instance;

  final List<PurchaseLine> _lines = [];
  int? _editingPurchaseId;
  Map<String, dynamic>? _editingPurchase;

  List<PurchaseLine> get lines => List.unmodifiable(_lines);
  int? get editingPurchaseId => _editingPurchaseId;
  bool get isEditing => _editingPurchaseId != null;

  double get subtotal => _lines.fold(0, (s, l) => s + l.amount);

  double taxAmount(SettingsProvider s, double base) =>
      s.taxEnabled ? base * s.taxPercent / 100 : 0;

  double totalAfter(SettingsProvider s, double discount) {
    final base = (subtotal - discount).clamp(0.0, double.infinity);
    return base + taxAmount(s, base);
  }

  void addManualItem({
    int?    itemId,
    required String itemName,
    required double qty,
    required String unit,
    required double price,
  }) {
    final idx = _lines.indexWhere(
        (l) => l.itemId == itemId && itemId != null);
    if (idx >= 0) {
      _lines[idx].qty += qty;
    } else {
      _lines.add(PurchaseLine(
          itemId: itemId, itemName: itemName,
          qty: qty, unit: unit, price: price));
    }
    notifyListeners();
  }

  void setQty(int index, double qty) {
    if (qty <= 0) {
      _lines.removeAt(index);
    } else {
      _lines[index].qty = qty;
    }
    notifyListeners();
  }

  void setQtyAndPrice(int index,
      {required double qty, required double price}) {
    if (qty <= 0) {
      _lines.removeAt(index);
    } else {
      _lines[index].qty   = qty;
      _lines[index].price = price;
    }
    notifyListeners();
  }

  void removeAt(int index) {
    _lines.removeAt(index);
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    _editingPurchaseId = null;
    _editingPurchase   = null;
    notifyListeners();
  }

  void loadForEdit(Map<String, dynamic> purchase) {
    _lines
      ..clear()
      ..addAll(((purchase['items'] as List?) ?? const [])
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .map((item) => PurchaseLine(
                itemId  : item['item_id'] as int?,
                itemName: item['item_name']?.toString() ?? 'Item',
                qty     : (item['quantity'] as num?)?.toDouble() ?? 0.0,
                unit    : item['unit']?.toString() ?? 'Kg',
                price   : (item['price'] as num?)?.toDouble() ?? 0.0,
              )));
    _editingPurchaseId = purchase['id'] as int?;
    _editingPurchase   = Map<String, dynamic>.from(purchase);
    notifyListeners();
  }

  // ── Save Purchase ─────────────────────────────────────────────────────────
  Future<String?> savePurchase({
    required SettingsProvider settings,
    required InventoryProvider inventory,
    CustomerModel? supplier,
    double discount      = 0,
    double paid          = 0,
    String paymentMethod = 'Cash',
    String notes         = '',
    DateTime? purchaseDate,
  }) async {
    if (_lines.isEmpty) return 'Add at least one item';

    final now      = DateTime.now().toIso8601String();
    final billDate = (purchaseDate ?? DateTime.now()).toIso8601String();
    final sub      = subtotal;
    final disc     = discount.clamp(0.0, sub);
    final base     = (sub - disc).clamp(0.0, double.infinity);
    final tax      = taxAmount(settings, base);
    final total    = base + tax;

    // unpaid portion of THIS bill
    final billBalance = (total - paid).clamp(0.0, double.infinity);

    final status = billBalance <= 0
        ? 'paid'
        : paid > 0
            ? 'partial'
            : 'unpaid';

    // ── FIX: Correct previous/current balance calculation ──────────────────
    //
    // supplier.balance = current DB balance (already reflects all past
    // purchases and payments). We must NOT add the full supplier.balance
    // to the new bill's unpaid portion blindly when editing.
    //
    // NEW purchase:
    //   prevBal = supplier.balance (what they already owe)
    //   curBal  = prevBal + billBalance (add this bill's unpaid portion)
    //
    // EDIT existing purchase:
    //   The old bill's unpaid balance was already added to supplier.balance.
    //   We need to remove the OLD bill's balance first, then add the new one.
    //   prevBal = supplier.balance - oldBillBalance  (undo old bill effect)
    //   curBal  = prevBal + billBalance              (add new bill's balance)
    //
    // This matches exactly how insertPartyPayment works in DatabaseHelper:
    //   newBal = oldBal - paymentAmount  (just adjusts by the delta)
    // ──────────────────────────────────────────────────────────────────────

    double prevBal;
    double curBal;

    if (_editingPurchaseId != null) {
      // Editing: undo the old bill's unpaid balance from supplier balance
      final oldBillBalance = (_editingPurchase?['balance'] as num?)?.toDouble() ?? 0.0;
      prevBal = (supplier?.balance ?? 0.0) - oldBillBalance;
      // prevBal can be negative if payments were made; keep as-is (no clamp)
      curBal  = prevBal + billBalance;
    } else {
      // New purchase: supplier.balance is the prev balance
      prevBal = supplier?.balance ?? 0.0;
      curBal  = prevBal + billBalance;
    }

    // curBal should never go below 0
    if (curBal < 0) curBal = 0;

    final purchaseNo = _editingPurchaseId != null
        ? (_editingPurchase?['purchase_no']?.toString() ?? '')
        : '${settings.purchasePrefix}${await settings.getNextPurchaseNo()}';

    final purchase = {
      'purchase_no'     : purchaseNo,
      'supplier_id'     : supplier?.id,
      'supplier_name'   : supplier?.name ?? '',
      'supplier_phone'  : supplier?.phone ?? '',
      'subtotal'        : sub,
      'discount'        : disc,
      'tax'             : tax,
      'total'           : total,
      'paid'            : paid,
      'balance'         : billBalance,
      'previous_balance': prevBal,
      'current_balance' : curBal,
      'payment_method'  : paymentMethod,
      'status'          : status,
      'notes'           : notes,
      'store_id'        : settings.currentStoreId,
      'created_at'      : billDate,
      'updated_at'      : now,
    };

    final items = _lines.map((l) => l.toMap()).toList();

    try {
      int id;
      if (_editingPurchaseId != null) {
        await _db.updatePurchase(
          purchaseId: _editingPurchaseId!,
          purchase  : purchase,
          items     : items,
        );
        id = _editingPurchaseId!;
      } else {
        id = await _db.insertPurchase(purchase, items);
      }

      // ── Sync to Firebase ──────────────────────────────────────────────────
      final saved = await _db.getPurchaseById(id);
      if (saved != null) await _sync.pushPurchase(saved);
      if (supplier != null && supplier.id != null) {
        final updatedSupplier = await _db.getCustomerById(supplier.id!);
        if (updatedSupplier != null) await _sync.pushCustomer(updatedSupplier);
      }

      await inventory.loadItems();
      clear();
      return null;
    } catch (e) {
      debugPrint('❌ savePurchase error: $e');
      return e.toString();
    }
  }
}