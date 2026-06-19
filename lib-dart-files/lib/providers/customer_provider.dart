import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/customer_model.dart';
import '../services/firebase_sync_service.dart';

class CustomerProvider extends ChangeNotifier {
  final _db   = DatabaseHelper.instance;
  final _sync = FirebaseSyncService.instance;

  List<CustomerModel> _customers = [];
  bool _loading = false;

  List<CustomerModel> get customers => _customers;
  bool get loading => _loading;

  Future<void> loadCustomers({String? search, String? partyType}) async {
    _loading = true;
    notifyListeners();
    final rows = await _db.getCustomers(search: search, partyType: partyType);
    _customers = rows.map(CustomerModel.fromMap).toList();
    _loading = false;
    notifyListeners();
  }

  Future<String?> addCustomer(Map<String, dynamic> data) async {
    try {
      final id = await _db.insertCustomer(data);
      // ── Sync to Firebase ──
      final saved = await _db.getCustomerById(id);
      if (saved != null) await _sync.pushCustomer(saved);
      await loadCustomers();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateCustomer(int id, Map<String, dynamic> data) async {
    try {
      await _db.updateCustomer(id, data);
      // ── Sync to Firebase ──
      final saved = await _db.getCustomerById(id);
      if (saved != null) await _sync.pushCustomer(saved);
      await loadCustomers();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteCustomer(int id) async {
    try {
      await _db.deleteCustomer(id);
      await loadCustomers();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}