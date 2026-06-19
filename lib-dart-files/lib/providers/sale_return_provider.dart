import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/customer_model.dart';
import '../providers/inventory_provider.dart';
import '../providers/settings_provider.dart';
import '../services/firebase_sync_service.dart';

class ReturnLine {
  final int?   itemId;
  final String itemName;
  double       qty;
  final String unit;
  double       price;

  ReturnLine({
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

class SaleReturnProvider extends ChangeNotifier {
  final _db   = DatabaseHelper.instance;
  final _sync = FirebaseSyncService.instance;

  final List<ReturnLine> _lines = [];

  List<ReturnLine> get lines => List.unmodifiable(_lines);

  double subtotal() => _lines.fold(0, (s, l) => s + l.amount);

  void addFromItem(Map<String, dynamic> item) {
    final id  = item['id'] as int?;
    final idx = _lines.indexWhere((l) => l.itemId == id && id != null);
    if (idx >= 0) {
      _lines[idx].qty += 1;
    } else {
      _lines.add(ReturnLine(
        itemId  : id,
        itemName: item['name'] as String? ?? '',
        qty     : 1,
        unit    : item['unit'] as String? ?? 'Kg',
        price   : (item['price'] as num?)?.toDouble() ?? 0,
      ));
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

  void removeAt(int index) {
    _lines.removeAt(index);
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }

  // ── Save Return ───────────────────────────────────────────────────────────
  Future<String?> saveReturn({
    required SettingsProvider settings,
    required InventoryProvider inventory,
    CustomerModel? customer,
  }) async {
    if (_lines.isEmpty) return 'Add at least one item';

    final now     = DateTime.now().toIso8601String();
    final sub     = subtotal();
    final prevBal = customer?.balance ?? 0.0;
    final curBal  = prevBal - sub;

    final returnNo = 'RET${DateTime.now().millisecondsSinceEpoch % 100000}';

    final ret = {
      'return_no'       : returnNo,
      'customer_id'     : customer?.id,
      'customer_name'   : customer?.name ?? '',
      'customer_phone'  : customer?.phone ?? '',
      'subtotal'        : sub,
      'discount'        : 0.0,
      'tax'             : 0.0,
      'total'           : sub,
      'previous_balance': prevBal,
      'current_balance' : curBal,
      'notes'           : '',
      'store_id'        : settings.currentStoreId,
      'created_at'      : now,
      'updated_at'      : now,
    };

    final items = _lines.map((l) => l.toMap()).toList();

    try {
      await _db.insertSaleReturn(ret, items);

      // ── Sync to Firebase ──────────────────────────────────────────────
      if (customer != null) {
        final updatedCustomer = await _db.getCustomerById(customer.id!);
        if (updatedCustomer != null) {
          await _sync.pushCustomer(updatedCustomer);
        }
      }

      await inventory.loadItems();
      clear();
      return null;
    } catch (e) {
      debugPrint('❌ saveReturn error: $e');
      return e.toString();
    }
  }
}