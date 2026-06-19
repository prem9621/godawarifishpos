import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';

/// FirebaseSyncService — syncs SQLite ↔ Firestore
/// Syncs: items, customers, invoices, purchases, expenses, users, stores
class FirebaseSyncService {
  FirebaseSyncService._();
  static final FirebaseSyncService instance = FirebaseSyncService._();

  final _local = DatabaseHelper.instance;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  bool get _firebaseReady => Firebase.apps.isNotEmpty;

  static const _items = 'items';
  static const _customers = 'customers';
  static const _invoices = 'invoices';
  static const _purchases = 'purchases';
  static const _expenses = 'expenses';
  static const _users = 'users';
  static const _stores = 'stores';

  StreamSubscription? _itemsSub;
  StreamSubscription? _customersSub;
  StreamSubscription? _invoicesSub;
  StreamSubscription? _purchasesSub;
  StreamSubscription? _expensesSub;
  StreamSubscription? _usersSub;
  StreamSubscription? _storesSub;

  bool _listening = false;
  String? _deviceId;
  Timer? _notifyDebounce;

  // Callback — called whenever remote data changes so UI can reload
  VoidCallback? onRemoteDataChanged;

  // ── Initialize ──────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (!_firebaseReady) {
      debugPrint('Firebase sync skipped: Firebase is not initialized yet');
      return;
    }
    await _ensureDeviceId();

    final conn = await Connectivity().checkConnectivity();
    if (conn.contains(ConnectivityResult.none)) {
      debugPrint('🔵 No internet — Firebase sync skipped');
      return;
    }

    await pullUsersAndStores();
    await pushAllToFirebase();
    startListening();

    debugPrint('✅ Firebase sync initialized');
  }

  // ── PULL users + stores FROM Firebase → local SQLite ───────────────────────
  // ✅ FIX: pass the Firestore doc.id alongside data so _upsert never silently
  //         skips records that are missing an 'id' field in the document body.

  Future<String> _ensureDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('firebase_sync_device_id');
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString('firebase_sync_device_id', id);
    }
    _deviceId = id;
    return id;
  }

  String _cloudDocId(String collection, Object? localId) {
    final id = localId?.toString();
    if (id == null || id.isEmpty) return const Uuid().v4();
    if (collection == _invoices ||
        collection == _items ||
        collection == _customers) {
      return '${_deviceId ?? 'unknown-device'}:$id';
    }
    return id;
  }

  Map<String, dynamic> _withSyncMeta(Map<String, dynamic> data) {
    return {
      ...data,
      'source_device_id': _deviceId,
      'source_local_id': data['id'],
      'synced_at': FieldValue.serverTimestamp(),
    };
  }

  Future<void> pullUsersAndStores() async {
    if (!_firebaseReady) return;
    try {
      // ── Stores ──
      final storeSnap = await _db.collection(_stores).get();
      for (final doc in storeSnap.docs) {
        // Merge the Firestore doc ID into the data map before upserting
        final data = <String, dynamic>{
          ...doc.data(),
          'firestore_doc_id': doc.id
        };
        await _upsertStore(data, docId: doc.id);
      }
      debugPrint('✅ Stores pulled: ${storeSnap.docs.length}');

      // ── Users ──
      final userSnap = await _db.collection(_users).get();
      for (final doc in userSnap.docs) {
        final data = <String, dynamic>{
          ...doc.data(),
          'firestore_doc_id': doc.id
        };
        await _upsertUser(data, docId: doc.id);
      }
      debugPrint('✅ Users pulled: ${userSnap.docs.length}');
    } catch (e) {
      debugPrint('❌ pullUsersAndStores error: $e');
    }
  }

  // ── Push ALL local data to Firebase ────────────────────────────────────────

  Future<void> pushAllToFirebase() async {
    if (!_firebaseReady) return;
    try {
      await Future.wait([
        _pushItems(),
        _pushCustomers(),
        _pushInvoices(),
        _pushPurchases(),
        _pushExpenses(),
        _pushUsers(),
        _pushStores(),
      ]);
      debugPrint('✅ All local data pushed to Firebase');
    } catch (e) {
      debugPrint('❌ pushAllToFirebase error: $e');
    }
  }

  Future<void> _pushItems() async {
    final items = await _local.getItems(allStores: true);
    for (final item in items) {
      final id = item['id']?.toString();
      if (id == null) continue;
      await _db
          .collection(_items)
          .doc(_cloudDocId(_items, id))
          .set(_withSyncMeta(item), SetOptions(merge: true));
    }
  }

  Future<void> _pushCustomers() async {
    final customers = await _local.getCustomers(allStores: true);
    for (final c in customers) {
      final id = c['id']?.toString();
      if (id == null) continue;
      await _db
          .collection(_customers)
          .doc(_cloudDocId(_customers, id))
          .set(_withSyncMeta(c), SetOptions(merge: true));
    }
  }

  Future<void> _pushInvoices() async {
    final invoices = await _local.getInvoices(allStores: true);
    for (final inv in invoices) {
      final id = inv['id']?.toString();
      if (id == null) continue;
      final full = await _local.getInvoiceById(inv['id'] as int);
      await _db.collection(_invoices).doc(_cloudDocId(_invoices, id)).set(
            _withSyncMeta({...inv, 'items': full?['items'] ?? []}),
            SetOptions(merge: true),
          );
    }
  }

  Future<void> _pushPurchases() async {
    final purchases = await _local.getPurchases(allStores: true);
    for (final p in purchases) {
      final id = p['id']?.toString();
      if (id == null) continue;
      await _db.collection(_purchases).doc(id).set({
        ...p,
        'synced_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _pushExpenses() async {
    final expenses = await _local.getExpenses(allStores: true);
    for (final e in expenses) {
      final id = e['id']?.toString();
      if (id == null) continue;
      await _db.collection(_expenses).doc(id).set({
        ...e,
        'synced_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _pushUsers() async {
    try {
      final users = await _local.getUsers();
      for (final u in users) {
        final id = u['id']?.toString();
        if (id == null) continue;
        await _db.collection(_users).doc(id).set({
          ...u,
          'synced_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('❌ _pushUsers: $e');
    }
  }

  Future<void> _pushStores() async {
    try {
      final stores = await _local.getStores();
      for (final s in stores) {
        final id = s['id']?.toString();
        if (id == null) continue;
        await _db.collection(_stores).doc(id).set({
          ...s,
          'synced_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('❌ _pushStores: $e');
    }
  }

  // ── Push single records ──────────────────────────────────────────────────────

  Future<void> pushItem(Map<String, dynamic> item) async {
    if (!_firebaseReady) return;
    try {
      final id = item['id']?.toString();
      if (id == null) return;
      await _ensureDeviceId();
      await _db
          .collection(_items)
          .doc(_cloudDocId(_items, id))
          .set(_withSyncMeta(item), SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ pushItem: $e');
    }
  }

  Future<void> pushCustomer(Map<String, dynamic> customer) async {
    if (!_firebaseReady) return;
    try {
      final id = customer['id']?.toString();
      if (id == null) return;
      await _ensureDeviceId();
      await _db
          .collection(_customers)
          .doc(_cloudDocId(_customers, id))
          .set(_withSyncMeta(customer), SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ pushCustomer: $e');
    }
  }

  Future<void> pushInvoice(int invoiceId) async {
    if (!_firebaseReady) return;
    try {
      await _ensureDeviceId();
      final full = await _local.getInvoiceById(invoiceId);
      if (full == null) return;
      await _db
          .collection(_invoices)
          .doc(_cloudDocId(_invoices, invoiceId))
          .set(
            _withSyncMeta(full),
            SetOptions(merge: true),
          );
      debugPrint('✅ Invoice pushed: $invoiceId');
    } catch (e) {
      debugPrint('❌ pushInvoice: $e');
    }
  }

  Future<void> pushPurchase(Map<String, dynamic> purchase) async {
    if (!_firebaseReady) return;
    try {
      final id = purchase['id']?.toString();
      if (id == null) return;
      await _db.collection(_purchases).doc(id).set({
        ...purchase,
        'synced_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ pushPurchase: $e');
    }
  }

  Future<void> pushExpense(Map<String, dynamic> expense) async {
    if (!_firebaseReady) return;
    try {
      final id = expense['id']?.toString();
      if (id == null) return;
      await _db.collection(_expenses).doc(id).set({
        ...expense,
        'synced_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ pushExpense: $e');
    }
  }

  Future<void> pushUser(Map<String, dynamic> user) async {
    if (!_firebaseReady) return;
    try {
      final id = user['id']?.toString();
      if (id == null) return;
      await _db.collection(_users).doc(id).set({
        ...user,
        'synced_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ pushUser: $e');
    }
  }

  Future<void> pushStore(Map<String, dynamic> store) async {
    if (!_firebaseReady) return;
    try {
      final id = store['id']?.toString();
      if (id == null) return;
      await _db.collection(_stores).doc(id).set({
        ...store,
        'synced_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ pushStore: $e');
    }
  }

  // ── Real-time listeners ──────────────────────────────────────────────────────

  void startListening() {
    if (!_firebaseReady) return;
    if (_listening) return;
    _listening = true;

    _itemsSub = _db.collection(_items).snapshots().listen((snap) async {
      bool changed = false;
      for (final c in snap.docChanges) {
        if (c.type == DocumentChangeType.added ||
            c.type == DocumentChangeType.modified) {
          final data = <String, dynamic>{...c.doc.data()!};
          await _upsertItem(data, docId: c.doc.id);
          changed = true;
        }
      }
      if (changed) _notifyChanged();
    });

    _customersSub = _db.collection(_customers).snapshots().listen((snap) async {
      bool changed = false;
      for (final c in snap.docChanges) {
        if (c.type == DocumentChangeType.added ||
            c.type == DocumentChangeType.modified) {
          final data = <String, dynamic>{...c.doc.data()!};
          await _upsertCustomer(data, docId: c.doc.id);
          changed = true;
        }
      }
      if (changed) _notifyChanged();
    });

    _invoicesSub = _db.collection(_invoices).snapshots().listen((snap) async {
      bool changed = false;
      for (final c in snap.docChanges) {
        if (c.type == DocumentChangeType.added ||
            c.type == DocumentChangeType.modified) {
          final data = <String, dynamic>{...c.doc.data()!};
          await _upsertInvoice(data, docId: c.doc.id);
          changed = true;
        }
      }
      if (changed) {
        debugPrint('🔄 New invoice from Firebase — refreshing UI');
        _notifyChanged();
      }
    });

    _purchasesSub = _db.collection(_purchases).snapshots().listen((snap) async {
      bool changed = false;
      for (final c in snap.docChanges) {
        if (c.type == DocumentChangeType.added ||
            c.type == DocumentChangeType.modified) {
          final data = <String, dynamic>{...c.doc.data()!};
          await _upsertPurchase(data, docId: c.doc.id);
          changed = true;
        }
      }
      if (changed) _notifyChanged();
    });

    _expensesSub = _db.collection(_expenses).snapshots().listen((snap) async {
      bool changed = false;
      for (final c in snap.docChanges) {
        if (c.type == DocumentChangeType.added ||
            c.type == DocumentChangeType.modified) {
          final data = <String, dynamic>{...c.doc.data()!};
          await _upsertExpense(data, docId: c.doc.id);
          changed = true;
        }
      }
      if (changed) _notifyChanged();
    });

    _usersSub = _db.collection(_users).snapshots().listen((snap) async {
      for (final c in snap.docChanges) {
        if (c.type == DocumentChangeType.added ||
            c.type == DocumentChangeType.modified) {
          final data = <String, dynamic>{...c.doc.data()!};
          await _upsertUser(data, docId: c.doc.id);
        }
      }
    });

    _storesSub = _db.collection(_stores).snapshots().listen((snap) async {
      for (final c in snap.docChanges) {
        if (c.type == DocumentChangeType.added ||
            c.type == DocumentChangeType.modified) {
          final data = <String, dynamic>{...c.doc.data()!};
          await _upsertStore(data, docId: c.doc.id);
        }
      }
    });

    debugPrint('✅ Firebase real-time listeners started');
  }

  void _notifyChanged() {
    _notifyDebounce?.cancel();
    _notifyDebounce = Timer(const Duration(milliseconds: 600), () {
      onRemoteDataChanged?.call();
    });
  }

  // ── Upsert helpers ───────────────────────────────────────────────────────────
  // ✅ FIX: every upsert now accepts an optional docId (Firestore string doc ID).
  //    Resolution order for the integer SQLite id:
  //      1. data['id'] if it's already an int in the document body
  //      2. int.tryParse(docId) if the doc was saved with a numeric string key
  //      3. hash of docId as a last-resort stable integer
  //    This guarantees _upsertStore/_upsertUser never silently return early.

  int _resolveId(Map<String, dynamic> data, String? docId) {
    final sourceDeviceId = data['source_device_id']?.toString();
    final sourceLocalId =
        int.tryParse(data['source_local_id']?.toString() ?? '');
    if (sourceDeviceId != null &&
        sourceDeviceId.isNotEmpty &&
        sourceDeviceId == _deviceId &&
        sourceLocalId != null) {
      return sourceLocalId;
    }

    if (sourceDeviceId != null &&
        sourceDeviceId.isNotEmpty &&
        sourceLocalId != null &&
        docId != null &&
        int.tryParse(docId) == null) {
      return _stablePositiveId(docId);
    }

    // 1. Prefer explicit integer id in the document body
    final bodyId = int.tryParse(data['id']?.toString() ?? '');
    if (bodyId != null) return bodyId;
    // 2. Try parsing the Firestore doc ID as an integer
    if (docId != null) {
      final docIntId = int.tryParse(docId);
      if (docIntId != null) return docIntId;
      // 3. Stable hash fallback so we always get a non-null int
      return _stablePositiveId(docId);
    }
    return -1;
  }

  int _stablePositiveId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  Future<void> _upsertItem(Map<String, dynamic> data, {String? docId}) async {
    try {
      final id = _resolveId(data, docId);
      if (id < 0) return;
      final db = await _local.database;
      final clean = _cleanData(data);
      clean['id'] = id;
      final existing =
          await db.query('items', where: 'id = ?', whereArgs: [id]);
      if (existing.isEmpty) {
        await db.insert('items', clean);
      } else {
        await db.update('items', clean, where: 'id = ?', whereArgs: [id]);
      }
    } catch (e) {
      debugPrint('❌ _upsertItem: $e');
    }
  }

  Future<void> _upsertCustomer(Map<String, dynamic> data,
      {String? docId}) async {
    try {
      final id = _resolveId(data, docId);
      if (id < 0) return;
      final db = await _local.database;
      final clean = _cleanData(data);
      clean['id'] = id;
      final existing =
          await db.query('customers', where: 'id = ?', whereArgs: [id]);
      if (existing.isEmpty) {
        await db.insert('customers', clean);
      } else {
        await db.update('customers', clean, where: 'id = ?', whereArgs: [id]);
      }
    } catch (e) {
      debugPrint('❌ _upsertCustomer: $e');
    }
  }

  Future<void> _upsertInvoice(Map<String, dynamic> data,
      {String? docId}) async {
    try {
      final id = _resolveId(data, docId);
      if (id < 0) return;
      final db = await _local.database;
      final items = data['items'] as List? ?? [];
      final clean = _cleanInvoiceData(data)..remove('items');
      clean['id'] = id;
      await _removeMissingInvoiceReferences(db, clean);
      await _avoidInvoiceNoConflict(db, clean, id, docId);
      final existing =
          await db.query('invoices', where: 'id = ?', whereArgs: [id]);
      if (existing.isEmpty) {
        await db.transaction((txn) async {
          await txn.insert('invoices', clean);
          for (final item in items) {
            final itemMap = Map<String, dynamic>.from(item as Map);
            itemMap['invoice_id'] = id;
            itemMap.remove('id');
            await txn.insert('invoice_items', _cleanInvoiceItemData(itemMap));
          }
        });
      } else {
        await db.transaction((txn) async {
          await txn.update('invoices', clean, where: 'id = ?', whereArgs: [id]);
          await txn.delete('invoice_items',
              where: 'invoice_id = ?', whereArgs: [id]);
          for (final item in items) {
            final itemMap = Map<String, dynamic>.from(item as Map);
            itemMap['invoice_id'] = id;
            itemMap.remove('id');
            await txn.insert('invoice_items', _cleanInvoiceItemData(itemMap));
          }
        });
      }
    } catch (e) {
      debugPrint('❌ _upsertInvoice: $e');
    }
  }

  Future<void> _removeMissingInvoiceReferences(
    dynamic db,
    Map<String, dynamic> invoice,
  ) async {
    final customerId = int.tryParse(invoice['customer_id']?.toString() ?? '');
    if (customerId == null) {
      invoice['customer_id'] = null;
      return;
    }
    final rows = await db.query(
      'customers',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [customerId],
      limit: 1,
    );
    if (rows.isEmpty) {
      invoice['customer_id'] = null;
    }
  }

  Future<void> _avoidInvoiceNoConflict(
    dynamic db,
    Map<String, dynamic> invoice,
    int invoiceId,
    String? docId,
  ) async {
    final baseNo = invoice['invoice_no']?.toString().trim() ?? '';
    if (baseNo.isEmpty) return;

    final conflict = await db.query(
      'invoices',
      columns: ['id'],
      where: 'invoice_no = ? AND id != ?',
      whereArgs: [baseNo, invoiceId],
      limit: 1,
    );
    if (conflict.isEmpty) return;

    final current = await db.query(
      'invoices',
      columns: ['invoice_no'],
      where: 'id = ?',
      whereArgs: [invoiceId],
      limit: 1,
    );
    final currentNo =
        current.isNotEmpty ? current.first['invoice_no']?.toString() : null;
    if (currentNo != null && currentNo.startsWith('$baseNo-')) {
      invoice['invoice_no'] = currentNo;
      return;
    }

    final suffix = _shortDocSuffix(docId ?? baseNo);
    var candidate = '$baseNo-$suffix';
    var count = 1;
    while (true) {
      final rows = await db.query(
        'invoices',
        columns: ['id'],
        where: 'invoice_no = ? AND id != ?',
        whereArgs: [candidate, invoiceId],
        limit: 1,
      );
      if (rows.isEmpty) {
        invoice['invoice_no'] = candidate;
        return;
      }
      count++;
      candidate = '$baseNo-$suffix$count';
    }
  }

  String _shortDocSuffix(String value) {
    final clean = value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (clean.length <= 4) return clean.padLeft(4, '0');
    return clean.substring(clean.length - 4).toUpperCase();
  }

  Future<void> _upsertPurchase(Map<String, dynamic> data,
      {String? docId}) async {
    try {
      final id = _resolveId(data, docId);
      if (id < 0) return;
      final db = await _local.database;
      final clean = _cleanData(data);
      clean['id'] = id;
      final existing =
          await db.query('purchases', where: 'id = ?', whereArgs: [id]);
      if (existing.isEmpty) {
        await db.insert('purchases', clean);
      } else {
        await db.update('purchases', clean, where: 'id = ?', whereArgs: [id]);
      }
    } catch (e) {
      debugPrint('❌ _upsertPurchase: $e');
    }
  }

  Future<void> _upsertExpense(Map<String, dynamic> data,
      {String? docId}) async {
    try {
      final id = _resolveId(data, docId);
      if (id < 0) return;
      final db = await _local.database;
      final clean = _cleanData(data);
      clean['id'] = id;
      final existing =
          await db.query('expenses', where: 'id = ?', whereArgs: [id]);
      if (existing.isEmpty) {
        await db.insert('expenses', clean);
      } else {
        await db.update('expenses', clean, where: 'id = ?', whereArgs: [id]);
      }
    } catch (e) {
      debugPrint('❌ _upsertExpense: $e');
    }
  }

  Future<void> _upsertUser(Map<String, dynamic> data, {String? docId}) async {
    try {
      final id = _resolveId(data, docId);
      if (id < 0) return;
      final db = await _local.database;
      final clean = _cleanData(data);
      clean['id'] = id;
      final existing =
          await db.query('users', where: 'id = ?', whereArgs: [id]);
      if (existing.isEmpty) {
        await db.insert('users', clean);
      } else {
        await db.update('users', clean, where: 'id = ?', whereArgs: [id]);
      }
      debugPrint('✅ User upserted: ${clean['name']} (id=$id)');
    } catch (e) {
      debugPrint('❌ _upsertUser: $e');
    }
  }

  Future<void> _upsertStore(Map<String, dynamic> data, {String? docId}) async {
    try {
      final id = _resolveId(data, docId);
      if (id < 0) return;
      final db = await _local.database;
      final clean = _cleanData(data);
      clean['id'] = id;
      final existing =
          await db.query('stores', where: 'id = ?', whereArgs: [id]);
      if (existing.isEmpty) {
        await db.insert('stores', clean);
      } else {
        await db.update('stores', clean, where: 'id = ?', whereArgs: [id]);
      }
      debugPrint('✅ Store upserted: ${clean['name']} (id=$id)');
    } catch (e) {
      debugPrint('❌ _upsertStore: $e');
    }
  }

  // ── Clean Firestore data for SQLite ─────────────────────────────────────────

  Map<String, dynamic> _cleanData(Map<String, dynamic> data) {
    final clean = <String, dynamic>{};
    for (final entry in data.entries) {
      final key = entry.key;
      final val = entry.value;
      // Skip Firestore-only fields
      if (key == 'synced_at' ||
          key == 'firestore_doc_id' ||
          key == 'source_device_id' ||
          key == 'source_local_id' ||
          key == 'items_summary' ||
          key.startsWith('_')) {
        continue;
      }
      if (val is Timestamp) {
        clean[key] = val.toDate().toIso8601String();
      } else if (val is List || val is Map) {
        continue; // handled separately for invoices
      } else {
        clean[key] = val;
      }
    }
    return clean;
  }

  // ── Stop listening ───────────────────────────────────────────────────────────

  Map<String, dynamic> _cleanInvoiceData(Map<String, dynamic> data) {
    const allowed = {
      'id',
      'invoice_no',
      'customer_id',
      'customer_name',
      'customer_phone',
      'subtotal',
      'discount',
      'tax',
      'shipping',
      'packaging',
      'total',
      'paid',
      'balance',
      'previous_balance',
      'current_balance',
      'payment_method',
      'status',
      'notes',
      'due_date',
      'invoice_date',
      'created_at',
      'updated_at',
      'store_id',
    };
    final clean = _cleanData(data)
      ..removeWhere((key, _) => !allowed.contains(key));
    final now = DateTime.now().toIso8601String();
    clean['invoice_no'] =
        clean['invoice_no']?.toString().trim().isNotEmpty == true
            ? clean['invoice_no'].toString().trim()
            : 'INV-${DateTime.now().millisecondsSinceEpoch}';
    clean['customer_name'] =
        clean['customer_name']?.toString().trim().isNotEmpty == true
            ? clean['customer_name'].toString().trim()
            : 'Walk-in Customer';
    clean['customer_phone'] = clean['customer_phone']?.toString() ?? '';
    clean['payment_method'] =
        clean['payment_method']?.toString().trim().isNotEmpty == true
            ? clean['payment_method'].toString().trim()
            : 'Cash';
    clean['status'] = clean['status']?.toString().trim().isNotEmpty == true
        ? clean['status'].toString().trim()
        : 'unpaid';
    clean['notes'] = clean['notes']?.toString() ?? '';
    clean['created_at'] = clean['created_at']?.toString() ?? now;
    clean['updated_at'] =
        clean['updated_at']?.toString() ?? clean['created_at'];
    clean['invoice_date'] =
        clean['invoice_date']?.toString() ?? clean['created_at'];
    for (final key in [
      'subtotal',
      'discount',
      'tax',
      'shipping',
      'packaging',
      'total',
      'paid',
      'balance',
      'previous_balance',
      'current_balance',
    ]) {
      clean[key] = _asDouble(clean[key]);
    }
    clean['store_id'] = int.tryParse(clean['store_id']?.toString() ?? '') ?? 1;
    return clean;
  }

  Map<String, dynamic> _cleanInvoiceItemData(Map<String, dynamic> data) {
    const allowed = {
      'invoice_id',
      'item_id',
      'item_name',
      'quantity',
      'unit',
      'price',
      'amount',
    };
    final clean = _cleanData(data)
      ..removeWhere((key, _) => !allowed.contains(key));
    clean['item_name'] =
        clean['item_name']?.toString().trim().isNotEmpty == true
            ? clean['item_name'].toString().trim()
            : 'Item';
    clean['unit'] = clean['unit']?.toString().trim().isNotEmpty == true
        ? clean['unit'].toString().trim()
        : 'Kg';
    for (final key in ['quantity', 'price', 'amount']) {
      clean[key] = _asDouble(clean[key]);
    }
    return clean;
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  void stopListening() {
    _itemsSub?.cancel();
    _customersSub?.cancel();
    _invoicesSub?.cancel();
    _purchasesSub?.cancel();
    _expensesSub?.cancel();
    _usersSub?.cancel();
    _storesSub?.cancel();
    _notifyDebounce?.cancel();
    _listening = false;
    debugPrint('🛑 Firebase listeners stopped');
  }
}
