import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

/// Single-instance SQLite helper for Godawari Fish POS.
/// v10: delivery_boys table added.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<void> preWarm() async {
    try {
      await database;
      debugPrint('✅ Database pre-warm complete');
    } catch (e, st) {
      debugPrint('❌ Database pre-warm FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);
    debugPrint('📂 DB path: $path');

    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await db.rawQuery('PRAGMA foreign_keys = ON');
        await db.rawQuery('PRAGMA journal_mode = WAL');
        await db.rawQuery('PRAGMA synchronous = NORMAL');
        await db.rawQuery('PRAGMA cache_size = 4000');
        await db.rawQuery('PRAGMA temp_store = MEMORY');
        debugPrint('✅ DB opened & PRAGMAs set');
      },
    );
  }

  // ── Schema ────────────────────────────────────────────────────────────────
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('🛠 Creating database schema v$version');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableCustomers} (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT    NOT NULL,
        phone      TEXT    DEFAULT '',
        address    TEXT    DEFAULT '',
        gst_number TEXT    DEFAULT '',
        balance    REAL    NOT NULL DEFAULT 0,
        party_type TEXT    NOT NULL DEFAULT 'customer',
        store_id   INTEGER NOT NULL DEFAULT 1,
        created_at TEXT    NOT NULL,
        updated_at TEXT    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableItems} (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        name           TEXT    NOT NULL,
        category       TEXT    DEFAULT '',
        unit           TEXT    NOT NULL DEFAULT 'Kg',
        price          REAL    NOT NULL DEFAULT 0,
        purchase_price REAL    NOT NULL DEFAULT 0,
        stock          REAL    NOT NULL DEFAULT 0,
        min_stock      REAL    NOT NULL DEFAULT 0,
        is_active      INTEGER NOT NULL DEFAULT 1,
        store_id       INTEGER NOT NULL DEFAULT 1,
        created_at     TEXT    NOT NULL,
        updated_at     TEXT    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableInvoices} (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_no       TEXT    NOT NULL UNIQUE,
        customer_id      INTEGER,
        customer_name    TEXT    NOT NULL DEFAULT 'Walk-in Customer',
        customer_phone   TEXT    NOT NULL DEFAULT '',
        subtotal         REAL    NOT NULL DEFAULT 0,
        discount         REAL    NOT NULL DEFAULT 0,
        tax              REAL    NOT NULL DEFAULT 0,
        shipping         REAL    NOT NULL DEFAULT 0,
        packaging        REAL    NOT NULL DEFAULT 0,
        total            REAL    NOT NULL DEFAULT 0,
        paid             REAL    NOT NULL DEFAULT 0,
        balance          REAL    NOT NULL DEFAULT 0,
        previous_balance REAL    NOT NULL DEFAULT 0,
        current_balance  REAL    NOT NULL DEFAULT 0,
        payment_method   TEXT    NOT NULL DEFAULT 'Cash',
        status           TEXT    NOT NULL DEFAULT 'unpaid',
        notes            TEXT    DEFAULT '',
        due_date         TEXT,
        invoice_date     TEXT,
        created_at       TEXT    NOT NULL,
        updated_at       TEXT    NOT NULL,
        store_id         INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (customer_id) REFERENCES ${AppConstants.tableCustomers}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableInvoiceItems} (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        item_id    INTEGER,
        item_name  TEXT    NOT NULL,
        quantity   REAL    NOT NULL DEFAULT 0,
        unit       TEXT    NOT NULL DEFAULT 'Kg',
        price      REAL    NOT NULL DEFAULT 0,
        amount     REAL    NOT NULL DEFAULT 0,
        FOREIGN KEY (invoice_id) REFERENCES ${AppConstants.tableInvoices}(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableExpenses} (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        title      TEXT    NOT NULL,
        amount     REAL    NOT NULL DEFAULT 0,
        category   TEXT    DEFAULT '',
        notes      TEXT    DEFAULT '',
        store_id   INTEGER NOT NULL DEFAULT 1,
        created_at TEXT    NOT NULL
      )
    ''');

    await _createPartyPaymentsTable(db);
    await _createPurchasesTables(db);
    await _createSaleReturnsTables(db);
    await _createStoresTable(db);
    await _createUsersTable(db);
    await _createDeliveryBoysTable(db);
    await _createIndexes(db);
    await _insertSampleData(db);

    debugPrint('✅ Database schema created successfully');
  }

  // ── STORES TABLE ──────────────────────────────────────────────────────────
  Future<void> _createStoresTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stores (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT    NOT NULL,
        phone      TEXT    DEFAULT '',
        address    TEXT    DEFAULT '',
        email      TEXT    DEFAULT '',
        is_active  INTEGER NOT NULL DEFAULT 1,
        created_at TEXT    NOT NULL,
        updated_at TEXT    NOT NULL
      )
    ''');

    final now = _nowStr;
    final existing = await db.query('stores', limit: 1);
    if (existing.isEmpty) {
      await db.insert('stores', {
        'name': AppConstants.shopName,
        'phone': AppConstants.shopPhone,
        'address': AppConstants.shopAddress,
        'email': AppConstants.shopEmail,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  // ── USERS TABLE ───────────────────────────────────────────────────────────
  Future<void> _createUsersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT    NOT NULL,
        phone      TEXT    DEFAULT '',
        role       TEXT    NOT NULL DEFAULT 'staff',
        pin        TEXT    NOT NULL DEFAULT '0000',
        store_id   INTEGER NOT NULL DEFAULT 1,
        is_active  INTEGER NOT NULL DEFAULT 1,
        created_at TEXT    NOT NULL,
        updated_at TEXT    NOT NULL
      )
    ''');

    final now = _nowStr;
    final existing = await db.query('users', limit: 1);
    if (existing.isEmpty) {
      await db.insert('users', {
        'name': 'Admin',
        'phone': '',
        'role': 'admin',
        'pin': '1234',
        'store_id': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  // ── DELIVERY BOYS TABLE ───────────────────────────────────────────────────
  Future<void> _createDeliveryBoysTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS delivery_boys (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT    NOT NULL,
        is_active  INTEGER NOT NULL DEFAULT 1,
        created_at TEXT    NOT NULL
      )
    ''');

    final existing = await db.query('delivery_boys', limit: 1);
    if (existing.isEmpty) {
      final now = _nowStr;
      for (final name in [
        'Imtiyaz Khan',
        'Prem Raje',
        'Abu bhai',
        'Aadil',
        'Janab',
        'Ajaz',
        'Sameer',
      ]) {
        await db.insert('delivery_boys', {
          'name': name,
          'is_active': 1,
          'created_at': now,
        });
      }
    }
  }

  Future<void> _createIndexes(Database db) async {
    final indexes = [
      'CREATE INDEX IF NOT EXISTS idx_invoices_customer  ON ${AppConstants.tableInvoices}(customer_id)',
      'CREATE INDEX IF NOT EXISTS idx_invoices_created   ON ${AppConstants.tableInvoices}(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_invoices_status    ON ${AppConstants.tableInvoices}(status)',
      'CREATE INDEX IF NOT EXISTS idx_customers_store    ON ${AppConstants.tableCustomers}(store_id)',
      'CREATE INDEX IF NOT EXISTS idx_invoice_items_inv  ON ${AppConstants.tableInvoiceItems}(invoice_id)',
      'CREATE INDEX IF NOT EXISTS idx_purchases_supplier ON ${AppConstants.tablePurchases}(supplier_id)',
      'CREATE INDEX IF NOT EXISTS idx_purchases_created  ON ${AppConstants.tablePurchases}(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_returns_customer   ON ${AppConstants.tableSaleReturns}(customer_id)',
      'CREATE INDEX IF NOT EXISTS idx_payments_customer  ON ${AppConstants.tablePartyPayments}(customer_id)',
      'CREATE INDEX IF NOT EXISTS idx_payments_store     ON ${AppConstants.tablePartyPayments}(store_id)',
      'CREATE INDEX IF NOT EXISTS idx_items_store        ON ${AppConstants.tableItems}(store_id)',
      'CREATE INDEX IF NOT EXISTS idx_items_active       ON ${AppConstants.tableItems}(is_active)',
    ];
    for (final sql in indexes) {
      try {
        await db.execute(sql);
      } catch (e) {
        debugPrint('Index creation warning: $e');
      }
    }
  }

  Future<void> _createPartyPaymentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE ${AppConstants.tablePartyPayments} (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id    INTEGER NOT NULL,
        amount         REAL    NOT NULL,
        payment_method TEXT    NOT NULL DEFAULT 'Cash',
        notes          TEXT    DEFAULT '',
        store_id       INTEGER NOT NULL DEFAULT 1,
        created_at     TEXT    NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES ${AppConstants.tableCustomers}(id)
      )
    ''');
  }

  Future<void> _createPurchasesTables(Database db) async {
    await db.execute('''
      CREATE TABLE ${AppConstants.tablePurchases} (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_no      TEXT    NOT NULL UNIQUE,
        supplier_id      INTEGER,
        supplier_name    TEXT    NOT NULL DEFAULT '',
        supplier_phone   TEXT    NOT NULL DEFAULT '',
        subtotal         REAL    NOT NULL DEFAULT 0,
        discount         REAL    NOT NULL DEFAULT 0,
        tax              REAL    NOT NULL DEFAULT 0,
        total            REAL    NOT NULL DEFAULT 0,
        paid             REAL    NOT NULL DEFAULT 0,
        balance          REAL    NOT NULL DEFAULT 0,
        previous_balance REAL    NOT NULL DEFAULT 0,
        current_balance  REAL    NOT NULL DEFAULT 0,
        payment_method   TEXT    NOT NULL DEFAULT 'Cash',
        status           TEXT    NOT NULL DEFAULT 'unpaid',
        notes            TEXT    DEFAULT '',
        store_id         INTEGER NOT NULL DEFAULT 1,
        created_at       TEXT    NOT NULL,
        updated_at       TEXT    NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES ${AppConstants.tableCustomers}(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE ${AppConstants.tablePurchaseItems} (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER NOT NULL,
        item_id     INTEGER,
        item_name   TEXT    NOT NULL,
        quantity    REAL    NOT NULL DEFAULT 0,
        unit        TEXT    NOT NULL DEFAULT 'Kg',
        price       REAL    NOT NULL DEFAULT 0,
        amount      REAL    NOT NULL DEFAULT 0,
        FOREIGN KEY (purchase_id) REFERENCES ${AppConstants.tablePurchases}(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createSaleReturnsTables(Database db) async {
    await db.execute('''
      CREATE TABLE ${AppConstants.tableSaleReturns} (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        return_no        TEXT    NOT NULL UNIQUE,
        customer_id      INTEGER,
        customer_name    TEXT    NOT NULL DEFAULT '',
        customer_phone   TEXT    NOT NULL DEFAULT '',
        subtotal         REAL    NOT NULL DEFAULT 0,
        discount         REAL    NOT NULL DEFAULT 0,
        tax              REAL    NOT NULL DEFAULT 0,
        total            REAL    NOT NULL DEFAULT 0,
        previous_balance REAL    NOT NULL DEFAULT 0,
        current_balance  REAL    NOT NULL DEFAULT 0,
        notes            TEXT    DEFAULT '',
        store_id         INTEGER NOT NULL DEFAULT 1,
        created_at       TEXT    NOT NULL,
        updated_at       TEXT    NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES ${AppConstants.tableCustomers}(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE ${AppConstants.tableSaleReturnItems} (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        return_id INTEGER NOT NULL,
        item_id   INTEGER,
        item_name TEXT    NOT NULL,
        quantity  REAL    NOT NULL DEFAULT 0,
        unit      TEXT    NOT NULL DEFAULT 'Kg',
        price     REAL    NOT NULL DEFAULT 0,
        amount    REAL    NOT NULL DEFAULT 0,
        FOREIGN KEY (return_id) REFERENCES ${AppConstants.tableSaleReturns}(id) ON DELETE CASCADE
      )
    ''');
  }

  // ── Migrations ────────────────────────────────────────────────────────────
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('🔄 DB upgrade: v$oldVersion → v$newVersion');

    if (oldVersion < 2) {
      try {
        await _createPartyPaymentsTable(db);
      } catch (e) {
        debugPrint('Migration v2: $e');
      }
    }
    if (oldVersion < 3) {
      try {
        await db.execute(
            "ALTER TABLE ${AppConstants.tableCustomers} ADD COLUMN party_type TEXT NOT NULL DEFAULT 'customer'");
      } catch (_) {}
      try {
        await _createPurchasesTables(db);
      } catch (_) {}
      try {
        await _createSaleReturnsTables(db);
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute(
            'ALTER TABLE ${AppConstants.tableItems} ADD COLUMN purchase_price REAL NOT NULL DEFAULT 0');
      } catch (e) {
        debugPrint('Migration v4 purchase_price: $e');
      }
      try {
        await db.execute(
            'ALTER TABLE ${AppConstants.tableInvoices} ADD COLUMN invoice_date TEXT');
      } catch (e) {
        debugPrint('Migration v4 invoice_date: $e');
      }
    }
    if (oldVersion < 5) {
      try {
        await db.execute(
            'ALTER TABLE ${AppConstants.tableInvoices} ADD COLUMN shipping REAL NOT NULL DEFAULT 0');
      } catch (e) {
        debugPrint('Migration v5 shipping: $e');
      }
      try {
        await db.execute(
            'ALTER TABLE ${AppConstants.tableInvoices} ADD COLUMN packaging REAL NOT NULL DEFAULT 0');
      } catch (e) {
        debugPrint('Migration v5 packaging: $e');
      }
    }
    if (oldVersion < 6) {
      for (final sql in [
        'ALTER TABLE ${AppConstants.tableInvoices}    ADD COLUMN store_id INTEGER NOT NULL DEFAULT 1',
        'ALTER TABLE ${AppConstants.tablePurchases}   ADD COLUMN store_id INTEGER NOT NULL DEFAULT 1',
        'ALTER TABLE ${AppConstants.tableSaleReturns} ADD COLUMN store_id INTEGER NOT NULL DEFAULT 1',
        'ALTER TABLE ${AppConstants.tableExpenses}    ADD COLUMN store_id INTEGER NOT NULL DEFAULT 1',
      ]) {
        try {
          await db.execute(sql);
        } catch (e) {
          debugPrint('Migration v6 alter: $e');
        }
      }
      try {
        await _createStoresTable(db);
      } catch (e) {
        debugPrint('Migration v6 stores: $e');
      }
      try {
        await _createUsersTable(db);
      } catch (e) {
        debugPrint('Migration v6 users: $e');
      }
    }
    if (oldVersion < 7) {
      try {
        await db.execute(
            'ALTER TABLE ${AppConstants.tableCustomers} ADD COLUMN gst_number TEXT DEFAULT ""');
      } catch (e) {
        debugPrint('Migration v7 gst_number: $e');
      }
    }
    if (oldVersion < 8) {
      for (final sql in [
        'ALTER TABLE ${AppConstants.tableCustomers} ADD COLUMN store_id INTEGER NOT NULL DEFAULT 1',
        'ALTER TABLE ${AppConstants.tableItems} ADD COLUMN store_id INTEGER NOT NULL DEFAULT 1',
      ]) {
        try {
          await db.execute(sql);
        } catch (e) {
          debugPrint('Migration v8 store_id: $e');
        }
      }
    }
    if (oldVersion < 9) {
      try {
        await db.execute(
            'ALTER TABLE ${AppConstants.tablePartyPayments} ADD COLUMN store_id INTEGER NOT NULL DEFAULT 1');
      } catch (e) {
        debugPrint('Migration v9 party payment store_id: $e');
      }
      try {
        await db.execute('''
          UPDATE ${AppConstants.tablePartyPayments}
          SET store_id = COALESCE((
            SELECT store_id FROM ${AppConstants.tableCustomers}
            WHERE ${AppConstants.tableCustomers}.id = ${AppConstants.tablePartyPayments}.customer_id
          ), 1)
        ''');
      } catch (e) {
        debugPrint('Migration v9 party payment backfill: $e');
      }
    }
    if (oldVersion < 10) {
      try {
        await _createDeliveryBoysTable(db);
      } catch (e) {
        debugPrint('Migration v10 delivery_boys: $e');
      }
    }
    try {
      await _createIndexes(db);
    } catch (_) {}
    debugPrint('✅ DB upgrade complete');
  }

  // ── Sample Data ───────────────────────────────────────────────────────────
  Future<int> _effectiveStoreId(int? storeId) async {
    if (storeId != null && storeId > 0) return storeId;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('current_store_id') ?? 1;
    return saved > 0 ? saved : 1;
  }

  Future<void> _insertSampleData(Database db) async {
    final now = _nowStr;
    final items = [
      {'name': 'Rohu Fish',        'category': 'Fresh Water Fish', 'unit': 'Kg', 'price': 180.0, 'purchase_price': 140.0, 'stock': 50.0},
      {'name': 'Catla Fish',       'category': 'Fresh Water Fish', 'unit': 'Kg', 'price': 200.0, 'purchase_price': 160.0, 'stock': 30.0},
      {'name': 'Prawn Tiger',      'category': 'Prawn & Shrimp',   'unit': 'Kg', 'price': 750.0, 'purchase_price': 600.0, 'stock': 20.0},
      {'name': 'Prawn Medium',     'category': 'Prawn & Shrimp',   'unit': 'Kg', 'price': 450.0, 'purchase_price': 350.0, 'stock': 15.0},
      {'name': 'Pomfret',          'category': 'Sea Water Fish',   'unit': 'Kg', 'price': 600.0, 'purchase_price': 480.0, 'stock': 10.0},
      {'name': 'Surmai (King Fish)','category': 'Sea Water Fish',  'unit': 'Kg', 'price': 800.0, 'purchase_price': 650.0, 'stock': 8.0},
      {'name': 'Bombay Duck',      'category': 'Sea Water Fish',   'unit': 'Kg', 'price': 300.0, 'purchase_price': 220.0, 'stock': 25.0},
      {'name': 'Bangda (Mackerel)','category': 'Sea Water Fish',   'unit': 'Kg', 'price': 250.0, 'purchase_price': 180.0, 'stock': 40.0},
      {'name': 'Crab',             'category': 'Crab & Lobster',   'unit': 'Kg', 'price': 500.0, 'purchase_price': 400.0, 'stock': 12.0},
      {'name': 'Squid',            'category': 'Squid & Octopus',  'unit': 'Kg', 'price': 400.0, 'purchase_price': 300.0, 'stock': 10.0},
      {'name': 'Chicken',          'category': 'Chicken',          'unit': 'Kg', 'price': 180.0, 'purchase_price': 140.0, 'stock': 30.0},
      {'name': 'Mutton',           'category': 'Mutton',           'unit': 'Kg', 'price': 650.0, 'purchase_price': 530.0, 'stock': 15.0},
    ];
    for (final item in items) {
      await db.insert(AppConstants.tableItems, {
        ...item,
        'is_active': 1,
        'min_stock': 2.0,
        'store_id': 1,
        'created_at': now,
        'updated_at': now,
      });
    }
    // Sample customer with NO hardcoded balance — balance is always derived
    await db.insert(AppConstants.tableCustomers, {
      'name': 'Bistro By Pizza Wala',
      'phone': '9049429465',
      'address': '',
      'gst_number': '',
      'balance': 0.0,
      'party_type': 'customer',
      'store_id': 1,
      'created_at': now,
      'updated_at': now,
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STORES CRUD
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getStores() async {
    final db = await database;
    return db.query('stores', where: 'is_active = 1', orderBy: 'id ASC');
  }

  Future<Map<String, dynamic>?> getStoreById(int id) async {
    final db = await database;
    final rows = await db.query('stores', where: 'id = ?', whereArgs: [id]);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<int> insertStore(Map<String, dynamic> store) async {
    final name = (store['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) throw ArgumentError('Store name cannot be empty');
    final db = await database;
    final now = _nowStr;
    try {
      final id = await db.insert('stores', {
        'name': name,
        'phone':   (store['phone']   as String?)?.trim() ?? '',
        'address': (store['address'] as String?)?.trim() ?? '',
        'email':   (store['email']   as String?)?.trim() ?? '',
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      debugPrint('✅ insertStore OK  id=$id  name=$name');
      return id;
    } catch (e, st) {
      debugPrint('❌ insertStore ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<int> updateStore(int id, Map<String, dynamic> data) async {
    final db = await database;
    return db.update('stores', {...data, 'updated_at': _nowStr},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteStore(int id) async {
    final db = await database;
    final stores = await db.query('stores', where: 'is_active = 1');
    if (stores.length <= 1) throw StateError('Cannot delete the last store');
    return db.update('stores', {'is_active': 0, 'updated_at': _nowStr},
        where: 'id = ?', whereArgs: [id]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  USERS CRUD
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getUsers({int? storeId}) async {
    final db = await database;
    final where = StringBuffer('is_active = 1');
    final args = <dynamic>[];
    if (storeId != null) {
      where.write(' AND store_id = ?');
      args.add(storeId);
    }
    return db.query('users',
        where: where.toString(),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'role ASC, name ASC');
  }

  Future<Map<String, dynamic>?> getUserById(int id) async {
    final db = await database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<Map<String, dynamic>?> loginWithPin(String pin,
      {int? storeId, int? userId}) async {
    final db = await database;
    final where = StringBuffer('pin = ? AND is_active = 1');
    final args = <dynamic>[pin];
    if (storeId != null) {
      where.write(' AND store_id = ?');
      args.add(storeId);
    }
    if (userId != null) {
      where.write(' AND id = ?');
      args.add(userId);
    }
    final rows = await db.query('users',
        where: where.toString(), whereArgs: args, limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<int> insertUser(Map<String, dynamic> user) async {
    final name = (user['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) throw ArgumentError('User name cannot be empty');
    final pin = (user['pin'] as String?)?.trim() ?? '';
    if (pin.length != 4) throw ArgumentError('PIN must be exactly 4 digits');
    final db = await database;
    final now = _nowStr;
    try {
      final id = await db.insert('users', {
        'name':  name,
        'phone': (user['phone'] as String?)?.trim() ?? '',
        'role':  (user['role'] as String?)?.trim().isNotEmpty == true
            ? user['role'] : 'staff',
        'pin':      pin,
        'store_id': (user['store_id'] as int?) ?? 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      debugPrint('✅ insertUser OK  id=$id  name=$name');
      return id;
    } catch (e, st) {
      debugPrint('❌ insertUser ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<int> updateUser(int id, Map<String, dynamic> data) async {
    final db = await database;
    return db.update('users', {...data, 'updated_at': _nowStr},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    final user = await getUserById(id);
    if (user != null && user['role'] == 'admin') {
      final admins =
          await db.query('users', where: "role = 'admin' AND is_active = 1");
      if (admins.length <= 1) throw StateError('Cannot delete the last admin');
    }
    return db.update('users', {'is_active': 0, 'updated_at': _nowStr},
        where: 'id = ?', whereArgs: [id]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DELIVERY BOYS CRUD
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getDeliveryBoys() async {
    final db = await database;
    return db.query('delivery_boys',
        where: 'is_active = 1', orderBy: 'name ASC');
  }

  Future<int> insertDeliveryBoy(String name) async {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError('Name cannot be empty');
    final db = await database;
    return db.insert('delivery_boys', {
      'name': n,
      'is_active': 1,
      'created_at': _nowStr,
    });
  }

  Future<int> deleteDeliveryBoy(int id) async {
    final db = await database;
    return db.update('delivery_boys', {'is_active': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CUSTOMERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> insertCustomer(Map<String, dynamic> customer) async {
    final name = (customer['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) throw ArgumentError('Customer name cannot be empty');
    final db = await database;
    final now = _nowStr;
    final row = {
      'name':       name,
      'phone':      (customer['phone']      as String?)?.trim() ?? '',
      'address':    (customer['address']    as String?)?.trim() ?? '',
      'gst_number': (customer['gst_number'] as String?)?.trim() ?? '',
      'balance':    (customer['balance']    as num?)?.toDouble() ?? 0.0,
      'party_type': (customer['party_type'] as String?)?.trim().isNotEmpty == true
          ? customer['party_type'] : 'customer',
      'store_id':   await _effectiveStoreId(customer['store_id'] as int?),
      'created_at': customer['created_at'] ?? now,
      'updated_at': customer['updated_at'] ?? now,
    };
    try {
      final id = await db.insert(AppConstants.tableCustomers, row);
      debugPrint('✅ insertCustomer OK  id=$id  name=$name');
      return id;
    } catch (e, st) {
      debugPrint('❌ insertCustomer ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCustomers({
    String? search,
    String? partyType,
    int? storeId,
    bool allStores = false,
  }) async {
    final db = await database;
    final where = StringBuffer('1=1');
    final args = <dynamic>[];
    if (!allStores) {
      where.write(' AND store_id = ?');
      args.add(await _effectiveStoreId(storeId));
    }
    if (search != null && search.isNotEmpty) {
      where.write(' AND (name LIKE ? OR phone LIKE ?)');
      args.addAll(['%$search%', '%$search%']);
    }
    if (partyType != null && partyType.isNotEmpty) {
      where.write(" AND COALESCE(party_type,'customer') = ?");
      args.add(partyType);
    }
    return db.query(
      AppConstants.tableCustomers,
      where: where.toString(),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name ASC',
    );
  }

  Future<Map<String, dynamic>?> getCustomerById(int id) async {
    final db = await database;
    final rows = await db.query(
      AppConstants.tableCustomers,
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<int> updateCustomer(int id, Map<String, dynamic> data) async {
    final db = await database;
    return db.update(
        AppConstants.tableCustomers, {...data, 'updated_at': _nowStr},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateCustomerBalance(int id, double balance) async {
    final db = await database;
    return db.update(AppConstants.tableCustomers,
        {'balance': balance, 'updated_at': _nowStr},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      await txn.delete(AppConstants.tablePartyPayments,
          where: 'customer_id = ?', whereArgs: [id]);
      await txn.delete(AppConstants.tableInvoiceItems,
          where:
              'invoice_id IN (SELECT id FROM ${AppConstants.tableInvoices} WHERE customer_id = ?)',
          whereArgs: [id]);
      await txn.delete(AppConstants.tableInvoices,
          where: 'customer_id = ?', whereArgs: [id]);
      await txn.delete(AppConstants.tablePurchases,
          where: 'supplier_id = ?', whereArgs: [id]);
      await txn.delete(AppConstants.tableSaleReturns,
          where: 'customer_id = ?', whereArgs: [id]);
      return txn.delete(AppConstants.tableCustomers,
          where: 'id = ?', whereArgs: [id]);
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ITEMS
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> insertItem(Map<String, dynamic> item) async {
    final name = (item['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) throw ArgumentError('Item name cannot be empty');
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    if (price < 0) throw ArgumentError('Price cannot be negative');
    final db = await database;
    final now = _nowStr;
    final row = {
      'name':           name,
      'category':       (item['category'] as String?)?.trim() ?? '',
      'unit':           (item['unit'] as String?)?.trim().isNotEmpty == true
          ? item['unit'] : 'Kg',
      'price':          price,
      'purchase_price': (item['purchase_price'] as num?)?.toDouble() ?? 0.0,
      'stock':          (item['stock']     as num?)?.toDouble() ?? 0.0,
      'min_stock':      (item['min_stock'] as num?)?.toDouble() ?? 0.0,
      'is_active':      (item['is_active'] as int?) ?? 1,
      'store_id':       await _effectiveStoreId(item['store_id'] as int?),
      'created_at':     item['created_at'] ?? now,
      'updated_at':     item['updated_at'] ?? now,
    };
    try {
      final id = await db.insert(AppConstants.tableItems, row);
      debugPrint('✅ insertItem OK  id=$id  name=$name');
      return id;
    } catch (e, st) {
      debugPrint('❌ insertItem ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getItems({
    String? search,
    String? category,
    int? storeId,
    bool allStores = false,
  }) async {
    final db = await database;
    final where = StringBuffer('is_active = 1');
    final args = <dynamic>[];
    if (!allStores) {
      where.write(' AND store_id = ?');
      args.add(await _effectiveStoreId(storeId));
    }
    if (search != null && search.isNotEmpty) {
      where.write(' AND name LIKE ?');
      args.add('%$search%');
    }
    if (category != null && category != 'All') {
      where.write(' AND category = ?');
      args.add(category);
    }
    return db.query(AppConstants.tableItems,
        where: where.toString(),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'name ASC');
  }

  Future<Map<String, dynamic>?> getItemById(int id) async {
    final db = await database;
    final rows = await db.query(
      AppConstants.tableItems,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<int> updateItem(int id, Map<String, dynamic> data) async {
    final db = await database;
    return db.update(AppConstants.tableItems,
        {...data, 'updated_at': _nowStr},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateItemStock(int id, double stock) async {
    final db = await database;
    return db.update(
        AppConstants.tableItems, {'stock': stock, 'updated_at': _nowStr},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteItem(int id) async {
    final db = await database;
    return db.update(
        AppConstants.tableItems, {'is_active': 0, 'updated_at': _nowStr},
        where: 'id = ?', whereArgs: [id]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  INVOICES
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> insertInvoice(
    Map<String, dynamic> invoice,
    List<Map<String, dynamic>> items,
  ) async {
    if (items.isEmpty) {
      throw ArgumentError('Cannot save an invoice with no items');
    }
    final invoiceNo = (invoice['invoice_no'] as String?)?.trim() ?? '';
    if (invoiceNo.isEmpty) throw ArgumentError('invoice_no is required');

    final now = _nowStr;
    final customerId = invoice['customer_id'];
    final currentBalance = customerId != null
        ? (invoice['current_balance'] as num?)?.toDouble() ?? 0.0
        : 0.0;

    final cleanInvoice = {
      'invoice_no':   invoiceNo,
      'customer_id':  customerId,
      'customer_name': (invoice['customer_name'] as String?)?.trim().isNotEmpty == true
          ? invoice['customer_name'] : 'Walk-in Customer',
      'customer_phone': (invoice['customer_phone'] as String?)?.trim() ?? '',
      'subtotal':   (invoice['subtotal']  as num?)?.toDouble() ?? 0.0,
      'discount':   (invoice['discount']  as num?)?.toDouble() ?? 0.0,
      'tax':        (invoice['tax']       as num?)?.toDouble() ?? 0.0,
      'shipping':   (invoice['shipping']  as num?)?.toDouble() ?? 0.0,
      'packaging':  (invoice['packaging'] as num?)?.toDouble() ?? 0.0,
      'total':      (invoice['total']     as num?)?.toDouble() ?? 0.0,
      'paid':       (invoice['paid']      as num?)?.toDouble() ?? 0.0,
      'balance':    (invoice['balance']   as num?)?.toDouble() ?? 0.0,
      'previous_balance': (invoice['previous_balance'] as num?)?.toDouble() ?? 0.0,
      'current_balance':  currentBalance,
      'payment_method': (invoice['payment_method'] as String?)?.trim().isNotEmpty == true
          ? invoice['payment_method'] : 'Cash',
      'status': (invoice['status'] as String?)?.trim().isNotEmpty == true
          ? invoice['status'] : 'unpaid',
      'notes':        (invoice['notes'] as String?)?.trim() ?? '',
      'due_date':     invoice['due_date'],
      'invoice_date': invoice['invoice_date'] ?? now,
      'store_id':     await _effectiveStoreId(invoice['store_id'] as int?),
      'created_at':   invoice['created_at'] ?? now,
      'updated_at':   invoice['updated_at'] ?? now,
    };

    final db = await database;
    try {
      final invoiceId = await db.transaction((txn) async {
        final id = await txn.insert(AppConstants.tableInvoices, cleanInvoice);
        for (final item in items) {
          final cleanItem = {
            'invoice_id': id,
            'item_id':    item['item_id'],
            'item_name':  (item['item_name'] as String?)?.trim() ?? 'Item',
            'quantity':   (item['quantity']  as num?)?.toDouble() ?? 0.0,
            'unit':       (item['unit'] as String?)?.trim().isNotEmpty == true
                ? item['unit'] : 'Kg',
            'price':  (item['price']  as num?)?.toDouble() ?? 0.0,
            'amount': (item['amount'] as num?)?.toDouble() ?? 0.0,
          };
          await txn.insert(AppConstants.tableInvoiceItems, cleanItem);
          await _deductStock(txn, cleanItem);
        }
        if (customerId != null) {
          await _recalculatePartyBalance(txn, customerId);
        }
        return id;
      });
      debugPrint('✅ insertInvoice COMPLETE  invoiceId=$invoiceId');
      return invoiceId;
    } catch (e, st) {
      debugPrint('❌ insertInvoice ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getInvoiceById(int id) async {
    final db = await database;
    final invoices = await db.query(AppConstants.tableInvoices,
        where: 'id = ?', whereArgs: [id]);
    if (invoices.isEmpty) return null;
    final invoice = Map<String, dynamic>.from(invoices.first);
    final items = await db.query(AppConstants.tableInvoiceItems,
        where: 'invoice_id = ?', whereArgs: [id]);
    invoice['items'] = items;
    if (items.isNotEmpty) {
      final names =
          items.map((e) => e['item_name']?.toString() ?? '').take(3).join(', ');
      invoice['items_summary'] = items.length > 3 ? '$names...' : names;
    } else {
      invoice['items_summary'] = '';
    }
    return invoice;
  }

  Future<List<Map<String, dynamic>>> getInvoices({
    String? search,
    String? status,
    DateTime? from,
    DateTime? to,
    int? customerId,
    int? storeId,
    int? limit,
    bool allStores = false,
  }) async {
    final db = await database;
    final where = StringBuffer('1=1');
    final args = <dynamic>[];

    if (search != null && search.isNotEmpty) {
      where.write(
          ' AND (inv.invoice_no LIKE ? OR inv.customer_name LIKE ? OR inv.customer_phone LIKE ?)');
      args.addAll(['%$search%', '%$search%', '%$search%']);
    }
    if (status != null && status != 'All') {
      where.write(' AND inv.status = ?');
      args.add(status.toLowerCase());
    }
    if (from != null) {
      where.write(' AND inv.created_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.write(' AND inv.created_at <= ?');
      args.add(to.add(const Duration(days: 1)).toIso8601String());
    }
    if (customerId != null) {
      where.write(' AND inv.customer_id = ?');
      args.add(customerId);
    }
    if (!allStores) {
      where.write(' AND inv.store_id = ?');
      args.add(await _effectiveStoreId(storeId));
    }

    final limitClause = limit != null ? 'LIMIT $limit' : '';

    final rows = await db.rawQuery('''
      SELECT
        inv.*,
        GROUP_CONCAT(ii.item_name, ', ') AS _items_concat,
        COUNT(ii.id) AS _items_count
      FROM ${AppConstants.tableInvoices} inv
      LEFT JOIN ${AppConstants.tableInvoiceItems} ii ON ii.invoice_id = inv.id
      WHERE ${where.toString()}
      GROUP BY inv.id
      ORDER BY inv.created_at DESC
      $limitClause
    ''', args.isEmpty ? null : args);

    return rows.map((row) {
      final m = Map<String, dynamic>.from(row);
      final concat = m.remove('_items_concat') as String? ?? '';
      final count  = (m.remove('_items_count') as num?)?.toInt() ?? 0;
      if (concat.isNotEmpty) {
        final names = concat.split(', ').take(2).join(', ');
        m['items_summary'] = count > 2 ? '$names...' : names;
      } else {
        m['items_summary'] = '';
      }
      return m;
    }).toList();
  }

  Future<int> updateInvoiceStatus(int id, String status, double paid) async {
    final db = await database;
    return db.update(AppConstants.tableInvoices,
        {'status': status, 'paid': paid, 'updated_at': _nowStr},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateInvoice({
    required int invoiceId,
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      // Restore old stock
      final oldItems = await txn.query(AppConstants.tableInvoiceItems,
          where: 'invoice_id = ?', whereArgs: [invoiceId]);
      for (final item in oldItems) {
        await _addStock(txn, item);
      }
      await txn.delete(AppConstants.tableInvoiceItems,
          where: 'invoice_id = ?', whereArgs: [invoiceId]);

      final currentBalance =
          (invoice['current_balance'] as num?)?.toDouble() ?? 0.0;
      final cleanInvoice = {
        'customer_id':  invoice['customer_id'],
        'customer_name': (invoice['customer_name'] as String?)?.trim().isNotEmpty == true
            ? invoice['customer_name'] : 'Walk-in Customer',
        'customer_phone': (invoice['customer_phone'] as String?)?.trim() ?? '',
        'subtotal':   (invoice['subtotal']  as num?)?.toDouble() ?? 0.0,
        'discount':   (invoice['discount']  as num?)?.toDouble() ?? 0.0,
        'tax':        (invoice['tax']       as num?)?.toDouble() ?? 0.0,
        'shipping':   (invoice['shipping']  as num?)?.toDouble() ?? 0.0,
        'packaging':  (invoice['packaging'] as num?)?.toDouble() ?? 0.0,
        'total':      (invoice['total']     as num?)?.toDouble() ?? 0.0,
        'paid':       (invoice['paid']      as num?)?.toDouble() ?? 0.0,
        'balance':    (invoice['balance']   as num?)?.toDouble() ?? 0.0,
        'previous_balance': (invoice['previous_balance'] as num?)?.toDouble() ?? 0.0,
        'current_balance':  currentBalance,
        'payment_method': (invoice['payment_method'] as String?)?.trim().isNotEmpty == true
            ? invoice['payment_method'] : 'Cash',
        'status': (invoice['status'] as String?)?.trim().isNotEmpty == true
            ? invoice['status'] : 'unpaid',
        'notes':    (invoice['notes'] as String?)?.trim() ?? '',
        'store_id': await _effectiveStoreId(invoice['store_id'] as int?),
        'updated_at': _nowStr,
      };

      await txn.update(AppConstants.tableInvoices, cleanInvoice,
          where: 'id = ?', whereArgs: [invoiceId]);

      for (final item in items) {
        final cleanItem = {
          'invoice_id': invoiceId,
          'item_id':    item['item_id'],
          'item_name':  (item['item_name'] as String?)?.trim() ?? 'Item',
          'quantity':   (item['quantity']  as num?)?.toDouble() ?? 0.0,
          'unit':       (item['unit'] as String?)?.trim().isNotEmpty == true
              ? item['unit'] : 'Kg',
          'price':  (item['price']  as num?)?.toDouble() ?? 0.0,
          'amount': (item['amount'] as num?)?.toDouble() ?? 0.0,
        };
        await txn.insert(AppConstants.tableInvoiceItems, cleanItem);
        await _deductStock(txn, cleanItem);
      }

      final cId = invoice['customer_id'];
      if (cId != null) {
        await _recalculatePartyBalance(txn, cId);
      }
    });
  }

  Future<int> deleteInvoice(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      // Restore stock first
      final oldItems = await txn.query(AppConstants.tableInvoiceItems,
          where: 'invoice_id = ?', whereArgs: [id]);
      for (final item in oldItems) {
        await _addStock(txn, item);
      }
      // Get customer_id before deleting
      final rows = await txn.query(AppConstants.tableInvoices,
          columns: ['customer_id'],
          where: 'id = ?', whereArgs: [id]);
      final customerId = rows.isNotEmpty ? rows.first['customer_id'] : null;

      // Delete items then invoice
      await txn.delete(AppConstants.tableInvoiceItems,
          where: 'invoice_id = ?', whereArgs: [id]);
      final deleted = await txn.delete(AppConstants.tableInvoices,
          where: 'id = ?', whereArgs: [id]);

      // Recalculate from scratch — bill is gone, remaining bills are correct
      if (customerId != null) {
        await _recalculatePartyBalance(txn, customerId);
      }
      return deleted;
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PURCHASES
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> insertPurchase(
    Map<String, dynamic> purchase,
    List<Map<String, dynamic>> items,
  ) async {
    if (items.isEmpty) {
      throw ArgumentError('Cannot save a purchase with no items');
    }
    final now = _nowStr;
    final cleanPurchase = {
      'purchase_no':   (purchase['purchase_no']   as String?)?.trim() ?? '',
      'supplier_id':   purchase['supplier_id'],
      'supplier_name': (purchase['supplier_name'] as String?)?.trim() ?? '',
      'supplier_phone':(purchase['supplier_phone'] as String?)?.trim() ?? '',
      'subtotal':  (purchase['subtotal']  as num?)?.toDouble() ?? 0.0,
      'discount':  (purchase['discount']  as num?)?.toDouble() ?? 0.0,
      'tax':       (purchase['tax']       as num?)?.toDouble() ?? 0.0,
      'total':     (purchase['total']     as num?)?.toDouble() ?? 0.0,
      'paid':      (purchase['paid']      as num?)?.toDouble() ?? 0.0,
      'balance':   (purchase['balance']   as num?)?.toDouble() ?? 0.0,
      'previous_balance': (purchase['previous_balance'] as num?)?.toDouble() ?? 0.0,
      'current_balance':  (purchase['current_balance']  as num?)?.toDouble() ?? 0.0,
      'payment_method': (purchase['payment_method'] as String?)?.trim().isNotEmpty == true
          ? purchase['payment_method'] : 'Cash',
      'status': (purchase['status'] as String?)?.trim().isNotEmpty == true
          ? purchase['status'] : 'unpaid',
      'notes':    (purchase['notes'] as String?)?.trim() ?? '',
      'store_id': await _effectiveStoreId(purchase['store_id'] as int?),
      'created_at': purchase['created_at'] ?? now,
      'updated_at': purchase['updated_at'] ?? now,
    };
    final db = await database;
    try {
      final purchaseId = await db.transaction((txn) async {
        final id = await txn.insert(AppConstants.tablePurchases, cleanPurchase);
        for (final item in items) {
          final cleanItem = {
            'purchase_id': id,
            'item_id':     item['item_id'],
            'item_name':   (item['item_name'] as String?)?.trim() ?? 'Item',
            'quantity':    (item['quantity']  as num?)?.toDouble() ?? 0.0,
            'unit':        (item['unit'] as String?)?.trim().isNotEmpty == true
                ? item['unit'] : 'Kg',
            'price':  (item['price']  as num?)?.toDouble() ?? 0.0,
            'amount': (item['amount'] as num?)?.toDouble() ?? 0.0,
          };
          await txn.insert(AppConstants.tablePurchaseItems, cleanItem);
          await _addStock(txn, cleanItem);
        }
        final supplierId = cleanPurchase['supplier_id'];
        if (supplierId != null) {
          await _recalculatePartyBalance(txn, supplierId);
        }
        return id;
      });
      debugPrint('✅ insertPurchase COMPLETE  id=$purchaseId');
      return purchaseId;
    } catch (e, st) {
      debugPrint('❌ insertPurchase ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPurchases({
    String? search,
    DateTime? from,
    DateTime? to,
    int? supplierId,
    int? storeId,
    bool allStores = false,
  }) async {
    final db = await database;
    final where = StringBuffer('1=1');
    final args = <dynamic>[];
    if (search != null && search.isNotEmpty) {
      where.write(
          ' AND (purchase_no LIKE ? OR supplier_name LIKE ? OR supplier_phone LIKE ?)');
      args.addAll(['%$search%', '%$search%', '%$search%']);
    }
    if (from != null) {
      where.write(' AND created_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.write(' AND created_at <= ?');
      args.add(to.add(const Duration(days: 1)).toIso8601String());
    }
    if (supplierId != null) {
      where.write(' AND supplier_id = ?');
      args.add(supplierId);
    }
    if (!allStores) {
      where.write(' AND store_id = ?');
      args.add(await _effectiveStoreId(storeId));
    }
    final rows = await db.rawQuery('''
      SELECT
        p.*,
        GROUP_CONCAT(pi.item_name, ', ') AS _items_concat,
        COUNT(pi.id) AS _items_count
      FROM ${AppConstants.tablePurchases} p
      LEFT JOIN ${AppConstants.tablePurchaseItems} pi ON pi.purchase_id = p.id
      WHERE ${where.toString()}
      GROUP BY p.id
      ORDER BY p.created_at DESC
    ''', args.isEmpty ? null : args);

    return rows.map((row) {
      final m = Map<String, dynamic>.from(row);
      final concat = m.remove('_items_concat') as String? ?? '';
      final count  = (m.remove('_items_count') as num?)?.toInt() ?? 0;
      if (concat.isNotEmpty) {
        final names = concat.split(', ').take(2).join(', ');
        m['items_summary'] = count > 2 ? '$names...' : names;
      } else {
        m['items_summary'] = '';
      }
      return m;
    }).toList();
  }

  Future<Map<String, dynamic>?> getPurchaseById(int id) async {
    final db = await database;
    final rows = await db.query(AppConstants.tablePurchases,
        where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final p = Map<String, dynamic>.from(rows.first);
    p['items'] = await db.query(AppConstants.tablePurchaseItems,
        where: 'purchase_id = ?', whereArgs: [id]);
    return p;
  }

  Future<void> updatePurchase({
    required int purchaseId,
    required Map<String, dynamic> purchase,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      // Restore old stock (purchases added stock, so revert = deduct)
      final oldItems = await txn.query(AppConstants.tablePurchaseItems,
          where: 'purchase_id = ?', whereArgs: [purchaseId]);
      for (final item in oldItems) {
        await _deductStock(txn, item);
      }
      await txn.delete(AppConstants.tablePurchaseItems,
          where: 'purchase_id = ?', whereArgs: [purchaseId]);

      final currentBalance =
          (purchase['current_balance'] as num?)?.toDouble() ?? 0.0;
      final cleanPurchase = {
        'supplier_id':   purchase['supplier_id'],
        'supplier_name': (purchase['supplier_name']  as String?)?.trim() ?? '',
        'supplier_phone':(purchase['supplier_phone'] as String?)?.trim() ?? '',
        'subtotal':  (purchase['subtotal']  as num?)?.toDouble() ?? 0.0,
        'discount':  (purchase['discount']  as num?)?.toDouble() ?? 0.0,
        'tax':       (purchase['tax']       as num?)?.toDouble() ?? 0.0,
        'total':     (purchase['total']     as num?)?.toDouble() ?? 0.0,
        'paid':      (purchase['paid']      as num?)?.toDouble() ?? 0.0,
        'balance':   (purchase['balance']   as num?)?.toDouble() ?? 0.0,
        'previous_balance': (purchase['previous_balance'] as num?)?.toDouble() ?? 0.0,
        'current_balance':  currentBalance,
        'payment_method': (purchase['payment_method'] as String?)?.trim().isNotEmpty == true
            ? purchase['payment_method'] : 'Cash',
        'status': (purchase['status'] as String?)?.trim().isNotEmpty == true
            ? purchase['status'] : 'unpaid',
        'notes':    (purchase['notes'] as String?)?.trim() ?? '',
        'store_id': await _effectiveStoreId(purchase['store_id'] as int?),
        'created_at': purchase['created_at'] ?? _nowStr,
        'updated_at': _nowStr,
      };

      await txn.update(AppConstants.tablePurchases, cleanPurchase,
          where: 'id = ?', whereArgs: [purchaseId]);

      for (final item in items) {
        final cleanItem = {
          'purchase_id': purchaseId,
          'item_id':     item['item_id'],
          'item_name':   (item['item_name'] as String?)?.trim() ?? 'Item',
          'quantity':    (item['quantity']  as num?)?.toDouble() ?? 0.0,
          'unit':        (item['unit'] as String?)?.trim().isNotEmpty == true
              ? item['unit'] : 'Kg',
          'price':  (item['price']  as num?)?.toDouble() ?? 0.0,
          'amount': (item['amount'] as num?)?.toDouble() ?? 0.0,
        };
        await txn.insert(AppConstants.tablePurchaseItems, cleanItem);
        await _addStock(txn, cleanItem);
      }

      final supplierId = purchase['supplier_id'];
      if (supplierId != null) {
        await _recalculatePartyBalance(txn, supplierId);
      }
    });
  }

  Future<int> deletePurchase(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      // Restore stock (purchases ADD stock, so deleting = deduct back)
      final oldItems = await txn.query(AppConstants.tablePurchaseItems,
          where: 'purchase_id = ?', whereArgs: [id]);
      for (final item in oldItems) {
        await _deductStock(txn, item);
      }
      // Get supplier_id before deleting
      final rows = await txn.query(AppConstants.tablePurchases,
          columns: ['supplier_id'],
          where: 'id = ?', whereArgs: [id]);
      final supplierId = rows.isNotEmpty ? rows.first['supplier_id'] : null;

      // Delete items then purchase
      await txn.delete(AppConstants.tablePurchaseItems,
          where: 'purchase_id = ?', whereArgs: [id]);
      final deleted = await txn.delete(AppConstants.tablePurchases,
          where: 'id = ?', whereArgs: [id]);

      // Recalculate from scratch
      if (supplierId != null) {
        await _recalculatePartyBalance(txn, supplierId);
      }
      return deleted;
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SALE RETURNS
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> insertSaleReturn(
    Map<String, dynamic> ret,
    List<Map<String, dynamic>> items,
  ) async {
    final now = _nowStr;
    final cleanRet = {
      'return_no':      (ret['return_no']      as String?)?.trim() ?? '',
      'customer_id':    ret['customer_id'],
      'customer_name':  (ret['customer_name']  as String?)?.trim() ?? '',
      'customer_phone': (ret['customer_phone'] as String?)?.trim() ?? '',
      'subtotal':  (ret['subtotal']  as num?)?.toDouble() ?? 0.0,
      'discount':  (ret['discount']  as num?)?.toDouble() ?? 0.0,
      'tax':       (ret['tax']       as num?)?.toDouble() ?? 0.0,
      'total':     (ret['total']     as num?)?.toDouble() ?? 0.0,
      'previous_balance': (ret['previous_balance'] as num?)?.toDouble() ?? 0.0,
      'current_balance':  (ret['current_balance']  as num?)?.toDouble() ?? 0.0,
      'notes':    (ret['notes'] as String?)?.trim() ?? '',
      'store_id': await _effectiveStoreId(ret['store_id'] as int?),
      'created_at': ret['created_at'] ?? now,
      'updated_at': ret['updated_at'] ?? now,
    };
    final db = await database;
    try {
      final returnId = await db.transaction((txn) async {
        final id = await txn.insert(AppConstants.tableSaleReturns, cleanRet);
        for (final item in items) {
          final cleanItem = {
            'return_id': id,
            'item_id':   item['item_id'],
            'item_name': (item['item_name'] as String?)?.trim() ?? 'Item',
            'quantity':  (item['quantity']  as num?)?.toDouble() ?? 0.0,
            'unit':      (item['unit'] as String?)?.trim().isNotEmpty == true
                ? item['unit'] : 'Kg',
            'price':  (item['price']  as num?)?.toDouble() ?? 0.0,
            'amount': (item['amount'] as num?)?.toDouble() ?? 0.0,
          };
          await txn.insert(AppConstants.tableSaleReturnItems, cleanItem);
          await _addStock(txn, cleanItem);
        }
        final cId = cleanRet['customer_id'];
        if (cId != null) {
          await _recalculatePartyBalance(txn, cId);
        }
        return id;
      });
      debugPrint('✅ insertSaleReturn COMPLETE  id=$returnId');
      return returnId;
    } catch (e, st) {
      debugPrint('❌ insertSaleReturn ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getSaleReturns({
    DateTime? from,
    DateTime? to,
    int? customerId,
    int? storeId,
    bool allStores = false,
  }) async {
    final db = await database;
    final where = StringBuffer('1=1');
    final args = <dynamic>[];
    if (from != null) {
      where.write(' AND created_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.write(' AND created_at <= ?');
      args.add(to.add(const Duration(days: 1)).toIso8601String());
    }
    if (customerId != null) {
      where.write(' AND customer_id = ?');
      args.add(customerId);
    }
    if (!allStores) {
      where.write(' AND store_id = ?');
      args.add(await _effectiveStoreId(storeId));
    }
    return db.query(AppConstants.tableSaleReturns,
        where: where.toString(),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'created_at DESC');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PARTY PAYMENTS
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> insertPartyPayment({
    required int customerId,
    required double amount,
    required String paymentMethod,
    String? notes,
  }) async {
    if (amount <= 0) throw ArgumentError('Payment amount must be positive');
    final db = await database;
    try {
      return db.transaction((txn) async {
        final cust = await txn.query(AppConstants.tableCustomers,
            where: 'id = ?', whereArgs: [customerId]);
        if (cust.isEmpty) throw StateError('Party not found (id=$customerId)');
        final storeId = (cust.first['store_id'] as num?)?.toInt() ??
            await _effectiveStoreId(null);
        final paymentId = await txn.insert(AppConstants.tablePartyPayments, {
          'customer_id':    customerId,
          'amount':         amount,
          'payment_method': paymentMethod.trim().isNotEmpty ? paymentMethod : 'Cash',
          'notes':          notes?.trim() ?? '',
          'store_id':       storeId,
          'created_at':     _nowStr,
        });
        await _recalculatePartyBalance(txn, customerId);
        return paymentId;
      });
    } catch (e, st) {
      debugPrint('❌ insertPartyPayment ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPartyPayments(int customerId,
      {int limit = 50}) async {
    final db = await database;
    return db.query(AppConstants.tablePartyPayments,
        where: 'customer_id = ?',
        whereArgs: [customerId],
        orderBy: 'created_at DESC',
        limit: limit);
  }

  Future<List<Map<String, dynamic>>> getRecentPartyPayments(
      {int limit = 40, int? storeId, bool allStores = false}) async {
    final db = await database;
    final where = StringBuffer('1=1');
    final args = <dynamic>[];
    if (!allStores) {
      where.write(' AND COALESCE(p.store_id, c.store_id, 1) = ?');
      args.add(await _effectiveStoreId(storeId));
    }
    args.add(limit);
    return db.rawQuery('''
      SELECT p.*, c.name AS party_name
      FROM   ${AppConstants.tablePartyPayments} p
      LEFT JOIN ${AppConstants.tableCustomers} c ON c.id = p.customer_id
      WHERE ${where.toString()}
      ORDER BY p.created_at DESC
      LIMIT ?
    ''', args);
  }

  Future<int> updatePartyPayment({
    required int paymentId,
    required int customerId,
    required double amount,
    required String paymentMethod,
    String? notes,
  }) async {
    if (amount <= 0) throw ArgumentError('Payment amount must be positive');
    final db = await database;
    return db.transaction((txn) async {
      final updated = await txn.update(
        AppConstants.tablePartyPayments,
        {
          'amount':         amount,
          'payment_method': paymentMethod.trim().isNotEmpty ? paymentMethod.trim() : 'Cash',
          'notes':          notes?.trim() ?? '',
        },
        where: 'id = ? AND customer_id = ?',
        whereArgs: [paymentId, customerId],
      );
      await _recalculatePartyBalance(txn, customerId);
      return updated;
    });
  }

  Future<int> deletePartyPayment({
    required int paymentId,
    required int customerId,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final deleted = await txn.delete(
        AppConstants.tablePartyPayments,
        where: 'id = ? AND customer_id = ?',
        whereArgs: [paymentId, customerId],
      );
      await _recalculatePartyBalance(txn, customerId);
      return deleted;
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  EXPENSES
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> insertExpense(Map<String, dynamic> expense) async {
    final title  = (expense['title']  as String?)?.trim() ?? '';
    if (title.isEmpty) throw ArgumentError('Expense title cannot be empty');
    final amount = (expense['amount'] as num?)?.toDouble() ?? 0.0;
    if (amount <= 0) throw ArgumentError('Expense amount must be positive');
    final db  = await database;
    final now = _nowStr;
    final row = {
      'title':    title,
      'amount':   amount,
      'category': (expense['category'] as String?)?.trim() ?? '',
      'notes':    (expense['notes']    as String?)?.trim() ?? '',
      'store_id': (expense['store_id'] as int?) ?? 1,
      'created_at': expense['created_at'] ?? now,
    };
    try {
      final id = await db.insert(AppConstants.tableExpenses, row);
      debugPrint('✅ insertExpense OK  id=$id  title=$title');
      return id;
    } catch (e, st) {
      debugPrint('❌ insertExpense ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getExpenses({
    DateTime? from,
    DateTime? to,
    int? storeId,
    bool allStores = false,
  }) async {
    final db = await database;
    final where = StringBuffer('1=1');
    final args = <dynamic>[];
    if (from != null) {
      where.write(' AND created_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.write(' AND created_at <= ?');
      args.add(to.add(const Duration(days: 1)).toIso8601String());
    }
    if (!allStores) {
      where.write(' AND store_id = ?');
      args.add(await _effectiveStoreId(storeId));
    }
    return db.query(AppConstants.tableExpenses,
        where: where.toString(),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'created_at DESC');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  REPORTS / DASHBOARD
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, double>> getDashboardStats({int? storeId}) async {
    final db = await database;
    final activeStoreId = await _effectiveStoreId(storeId);
    final now        = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();

    final storeFilter     = ' AND store_id = $activeStoreId';
    final storeFilterBase = ' WHERE store_id = $activeStoreId';

    final results = await Future.wait([
      db.rawQuery(
          'SELECT COALESCE(SUM(total),0) AS total, COALESCE(SUM(paid),0) AS paid, COUNT(*) AS count '
          'FROM ${AppConstants.tableInvoices} WHERE created_at >= ?$storeFilter',
          [todayStart]),
      db.rawQuery(
          'SELECT COALESCE(SUM(total),0) AS total FROM ${AppConstants.tableInvoices} WHERE created_at >= ?$storeFilter',
          [monthStart]),
      db.rawQuery(
          'SELECT COALESCE(SUM(balance),0) AS pending FROM ${AppConstants.tableInvoices} WHERE status != "paid"$storeFilter'),
      db.rawQuery(
          'SELECT COUNT(*) AS count FROM ${AppConstants.tableCustomers}$storeFilterBase'),
      db.rawQuery(
          "SELECT COALESCE(SUM(balance),0) AS s FROM ${AppConstants.tableCustomers} "
          "WHERE COALESCE(party_type,'customer') = 'customer' AND balance > 0$storeFilter"),
    ]);

    return {
      'today_total':      (results[0].first['total']   as num?)?.toDouble() ?? 0,
      'today_paid':       (results[0].first['paid']    as num?)?.toDouble() ?? 0,
      'today_count':      (results[0].first['count']   as num?)?.toDouble() ?? 0,
      'month_total':      (results[1].first['total']   as num?)?.toDouble() ?? 0,
      'pending_balance':  (results[2].first['pending'] as num?)?.toDouble() ?? 0,
      'customer_count':   (results[3].first['count']   as num?)?.toDouble() ?? 0,
      'to_receive':       (results[4].first['s']       as num?)?.toDouble() ?? 0,
    };
  }

  Future<double> getTotalPartyBalance() async {
    final db = await database;
    final storeId = await _effectiveStoreId(null);
    final r = await db.rawQuery(
        'SELECT COALESCE(SUM(balance),0) AS s FROM ${AppConstants.tableCustomers} WHERE store_id = ?',
        [storeId]);
    return (r.first['s'] as num?)?.toDouble() ?? 0;
  }

  Future<double> getTotalStockQuantity() async {
    final db = await database;
    final storeId = await _effectiveStoreId(null);
    final r = await db.rawQuery(
        'SELECT COALESCE(SUM(stock),0) AS s FROM ${AppConstants.tableItems} WHERE is_active = 1 AND store_id = ?',
        [storeId]);
    return (r.first['s'] as num?)?.toDouble() ?? 0;
  }

  Future<double> getSumBalanceForPartyType(String partyType) async {
    final db = await database;
    final storeId = await _effectiveStoreId(null);
    final r = await db.rawQuery(
        "SELECT COALESCE(SUM(balance),0) AS s FROM ${AppConstants.tableCustomers} "
        "WHERE COALESCE(party_type,'customer') = ? AND store_id = ?",
        [partyType, storeId]);
    return (r.first['s'] as num?)?.toDouble() ?? 0;
  }

  Future<double> getMonthPurchaseTotal({int? storeId}) async {
    final db = await database;
    final from = DateTime(DateTime.now().year, DateTime.now().month, 1).toIso8601String();
    final activeStoreId = await _effectiveStoreId(storeId);
    final r = await db.rawQuery(
        'SELECT COALESCE(SUM(total),0) AS s FROM ${AppConstants.tablePurchases} WHERE created_at >= ? AND store_id = ?',
        [from, activeStoreId]);
    return (r.first['s'] as num?)?.toDouble() ?? 0;
  }

  Future<double> getMonthExpenseTotal({int? storeId}) async {
    final db = await database;
    final from = DateTime(DateTime.now().year, DateTime.now().month, 1).toIso8601String();
    final activeStoreId = await _effectiveStoreId(storeId);
    final r = await db.rawQuery(
        'SELECT COALESCE(SUM(amount),0) AS s FROM ${AppConstants.tableExpenses} WHERE created_at >= ? AND store_id = ?',
        [from, activeStoreId]);
    return (r.first['s'] as num?)?.toDouble() ?? 0;
  }

  Future<List<Map<String, dynamic>>> getSalesReport(DateTime from, DateTime to,
      {int? storeId}) async {
    final db = await database;
    final activeStoreId = await _effectiveStoreId(storeId);
    return db.rawQuery('''
      SELECT date(created_at) AS date,
             COUNT(*)         AS count,
             SUM(total)       AS total,
             SUM(paid)        AS paid,
             SUM(balance)     AS balance
      FROM   ${AppConstants.tableInvoices}
      WHERE  created_at >= ? AND created_at <= ? AND store_id = ?
      GROUP BY date(created_at)
      ORDER BY date DESC
    ''', [
      from.toIso8601String(),
      to.add(const Duration(days: 1)).toIso8601String(),
      activeStoreId,
    ]);
  }

  Future<List<Map<String, dynamic>>> getTopItems(DateTime from, DateTime to,
      {int? storeId}) async {
    final db = await database;
    final activeStoreId = await _effectiveStoreId(storeId);
    return db.rawQuery('''
      SELECT ii.item_name,
             SUM(ii.quantity) AS total_qty,
             SUM(ii.amount)   AS total_amount
      FROM   ${AppConstants.tableInvoiceItems} ii
      JOIN   ${AppConstants.tableInvoices}     inv ON ii.invoice_id = inv.id
      WHERE  inv.created_at >= ? AND inv.created_at <= ? AND inv.store_id = ?
      GROUP BY ii.item_name
      ORDER BY total_amount DESC
      LIMIT 10
    ''', [
      from.toIso8601String(),
      to.add(const Duration(days: 1)).toIso8601String(),
      activeStoreId,
    ]);
  }

  Future<List<Map<String, dynamic>>> getDayBook(
      {int limit = 150, int? storeId}) async {
    final db = await database;
    final from = DateTime.now()
        .subtract(const Duration(days: 120))
        .toIso8601String();
    final activeStoreId = await _effectiveStoreId(storeId);

    final rows = await db.rawQuery('''
      SELECT 'sale'    AS kind,
             'Sale · ' || invoice_no AS title,
             customer_name           AS subtitle,
             total                   AS amount,
             created_at              AS ts
      FROM ${AppConstants.tableInvoices}
      WHERE created_at >= ? AND store_id = $activeStoreId

      UNION ALL

      SELECT 'purchase' AS kind,
             'Purchase · ' || purchase_no AS title,
             supplier_name                AS subtitle,
             total                        AS amount,
             created_at                   AS ts
      FROM ${AppConstants.tablePurchases}
      WHERE created_at >= ? AND store_id = $activeStoreId

      UNION ALL

      SELECT 'return' AS kind,
             'Return · ' || return_no AS title,
             customer_name            AS subtitle,
             total                    AS amount,
             created_at               AS ts
      FROM ${AppConstants.tableSaleReturns}
      WHERE created_at >= ? AND store_id = $activeStoreId

      UNION ALL

      SELECT 'expense' AS kind,
             'Expense · ' || title AS title,
             category              AS subtitle,
             amount                AS amount,
             created_at            AS ts
      FROM ${AppConstants.tableExpenses}
      WHERE created_at >= ? AND store_id = $activeStoreId

      UNION ALL

      SELECT 'payment'                             AS kind,
             'Payment · ' || COALESCE(c.name, '') AS title,
             p.payment_method                      AS subtitle,
             p.amount                              AS amount,
             p.created_at                          AS ts
      FROM ${AppConstants.tablePartyPayments} p
      LEFT JOIN ${AppConstants.tableCustomers} c ON c.id = p.customer_id
      WHERE p.created_at >= ? AND COALESCE(p.store_id, c.store_id, 1) = $activeStoreId

      ORDER BY ts DESC
      LIMIT ?
    ''', [from, from, from, from, from, limit]);

    return rows.map((r) {
      final m = Map<String, dynamic>.from(r);
      m['_ms'] =
          DateTime.tryParse(m['ts'] as String? ?? '')?.millisecondsSinceEpoch ?? 0;
      return m;
    }).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PRIVATE HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  String get _nowStr => DateTime.now().toIso8601String();

  Future<void> _deductStock(Transaction txn, Map<String, dynamic> item) async {
    final itemId = item['item_id'];
    if (itemId == null) return;
    final rows = await txn.query(AppConstants.tableItems,
        columns: ['stock'], where: 'id = ?', whereArgs: [itemId]);
    if (rows.isEmpty) return;
    final stock = (rows.first['stock'] as num).toDouble();
    final qty   = (item['quantity']   as num).toDouble();
    await txn.update(
      AppConstants.tableItems,
      {'stock': (stock - qty).clamp(0.0, double.infinity), 'updated_at': _nowStr},
      where: 'id = ?', whereArgs: [itemId],
    );
  }

  Future<void> _addStock(Transaction txn, Map<String, dynamic> item) async {
    final itemId = item['item_id'];
    if (itemId == null) return;
    final rows = await txn.query(AppConstants.tableItems,
        columns: ['stock'], where: 'id = ?', whereArgs: [itemId]);
    if (rows.isEmpty) return;
    final stock = (rows.first['stock'] as num).toDouble();
    final qty   = (item['quantity']   as num).toDouble();
    await txn.update(
      AppConstants.tableItems,
      {'stock': stock + qty, 'updated_at': _nowStr},
      where: 'id = ?', whereArgs: [itemId],
    );
  }

  Future<void> _syncCustomerBalance(
      Transaction txn, dynamic customerId, dynamic newBalance) async {
    if (customerId == null) return;
    await txn.update(
      AppConstants.tableCustomers,
      {'balance': (newBalance as num?)?.toDouble() ?? 0.0, 'updated_at': _nowStr},
      where: 'id = ?', whereArgs: [customerId],
    );
  }

  /// Recalculates a party's balance from scratch.
  ///
  /// Formula:
  ///   balance = openingBalance + SUM(bill.total) - SUM(bill.paid) - SUM(partyPayments)
  ///
  /// Where openingBalance = previous_balance on the oldest bill for this party.
  /// This is always correct regardless of edits, deletes, or partial payments.
  Future<void> _recalculatePartyBalance(
    Transaction txn,
    dynamic customerId, {
    double? fallbackBalance,
  }) async {
    if (customerId == null) return;

    // 1. Party type
    final customerRows = await txn.query(
      AppConstants.tableCustomers,
      columns: ['party_type'],
      where: 'id = ?',
      whereArgs: [customerId],
    );
    if (customerRows.isEmpty) return;
    final partyType =
        customerRows.first['party_type']?.toString().toLowerCase() ?? 'customer';

    final billTable   = partyType == 'supplier'
        ? AppConstants.tablePurchases
        : AppConstants.tableInvoices;
    final partyColumn = partyType == 'supplier' ? 'supplier_id' : 'customer_id';

    // 2. Count remaining bills
    final countRows = await txn.rawQuery(
      'SELECT COUNT(*) AS cnt FROM $billTable WHERE $partyColumn = ?',
      [customerId],
    );
    final billCount = (countRows.first['cnt'] as num?)?.toInt() ?? 0;

    double newBalance;

    if (billCount == 0) {
      // No bills — party is fully settled (or never had bills)
      newBalance = fallbackBalance ?? 0.0;
    } else {
      // 3. Opening balance from oldest bill
      final oldestRows = await txn.rawQuery(
        'SELECT previous_balance FROM $billTable '
        'WHERE $partyColumn = ? ORDER BY created_at ASC, id ASC LIMIT 1',
        [customerId],
      );
      final openingBalance = oldestRows.isNotEmpty
          ? (oldestRows.first['previous_balance'] as num?)?.toDouble() ?? 0.0
          : 0.0;

      // 4. Sum of all bill totals and bill-level paid amounts
      final billRows = await txn.rawQuery(
        'SELECT COALESCE(SUM(total), 0) AS sum_total, '
        'COALESCE(SUM(paid), 0) AS sum_paid '
        'FROM $billTable WHERE $partyColumn = ?',
        [customerId],
      );
      final sumTotal   = (billRows.first['sum_total'] as num?)?.toDouble() ?? 0.0;
      final sumBillPaid= (billRows.first['sum_paid']  as num?)?.toDouble() ?? 0.0;

      // 5. Standalone party payments
      final payRows = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) AS sum_pay '
        'FROM ${AppConstants.tablePartyPayments} WHERE customer_id = ?',
        [customerId],
      );
      final sumPayments = (payRows.first['sum_pay'] as num?)?.toDouble() ?? 0.0;

      // 6. Final balance
      newBalance = openingBalance + sumTotal - sumBillPaid - sumPayments;
    }

    await txn.update(
      AppConstants.tableCustomers,
      {'balance': newBalance, 'updated_at': _nowStr},
      where: 'id = ?',
      whereArgs: [customerId],
    );

    debugPrint(
      '💰 _recalculatePartyBalance  id=$customerId  '
      'billCount=$billCount  newBalance=$newBalance',
    );
  }
}