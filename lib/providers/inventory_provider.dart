import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../services/firebase_sync_service.dart';

class InventoryProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  final _sync = FirebaseSyncService.instance;

  List<Map<String, dynamic>> _items = [];
  bool _loading = false;

  List<Map<String, dynamic>> get items => _items;
  bool get loading => _loading;

  Future<void> loadItems({String? search, String? category}) async {
    _loading = true;
    notifyListeners();
    try {
      _items = await _db.getItems(search: search, category: category);
    } catch (e) {
      // ✅ FIX: a failed query used to leave _loading stuck true forever.
      debugPrint('❌ loadItems error: $e');
      _items = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Called from items_screen after direct DB insert
  Future<void> syncItemToFirebase(int id) async {
    try {
      final item = await _db.getItemById(id);
      if (item != null) await _sync.pushItem(item);
    } catch (e) {
      debugPrint('❌ syncItemToFirebase error: $e');
    }
  }

  Future<String?> addItem(Map<String, dynamic> item) async {
    try {
      final id = await _db.insertItem(item);
      await syncItemToFirebase(id);
      await loadItems();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateItem(int id, Map<String, dynamic> data) async {
    try {
      await _db.updateItem(id, data);
      await syncItemToFirebase(id);
      await loadItems();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ✅ Used by items_screen._editStock
  Future<String?> setStock(int id, double stock) async {
    try {
      await _db.updateItemStock(id, stock);
      await syncItemToFirebase(id);
      await loadItems();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ✅ Used by items_screen._deleteItem
  Future<String?> deactivateItem(int id) async {
    try {
      await _db.deleteItem(id);
      await loadItems();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Alias for compatibility
  Future<String?> deleteItem(int id) => deactivateItem(id);
  Future<String?> updateStock(int id, double stock) => setStock(id, stock);
}