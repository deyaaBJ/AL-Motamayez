import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DBHelper {
  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  Future<Database> initDb() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    String folderPath = join(Directory.current.path, 'data');
    Directory(folderPath).createSync(recursive: true);

    String path = join(folderPath, 'shopmate.db');

    Database database = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );

    // إضافة الفواتير التجريبية
    await _insertTestInvoices(database);

    // 🔄 التعليق على الأرشفة مؤقتًا لتجربة الفواتير
    await _archiveOldInvoices(database);

    return database;
  }

  Future<void> _insertTestInvoices(Database db) async {
    // 🔹 إضافة الفواتير التجريبية
    final invoice1Id = await db.insert('sales', {
      'date': DateTime.now().subtract(Duration(days: 366)).toIso8601String(),
      'total_amount': 500,
      'total_profit': 100,
      'customer_id': null,
      'payment_type': 'cash',
      'show_for_tax': 1,
    });

    final invoice2Id = await db.insert('sales', {
      'date':
          DateTime.now().subtract(Duration(days: 365 * 4)).toIso8601String(),
      'total_amount': 800,
      'total_profit': 200,
      'customer_id': null,
      'payment_type': 'credit',
      'show_for_tax': 1,
    });

    final invoice3Id = await db.insert('sales', {
      'date': DateTime(2025, 5, 15).toIso8601String(),
      'total_amount': 1000,
      'total_profit': 250,
      'customer_id': null,
      'payment_type': 'cash',
      'show_for_tax': 1,
    });

    print('✅ تم إضافة الفواتير التجريبية!');

    // 🔹 إضافة عناصر لكل فاتورة
    await db.insert('sale_items', {
      'sale_id': invoice1Id,
      'product_id': 1,
      'unit_id': null,
      'quantity': 2,
      'unit_type': 'piece',
      'custom_unit_name': null,
      'price': 100,
      'cost_price': 50,
      'subtotal': 200,
      'profit': 100,
    });

    await db.insert('sale_items', {
      'sale_id': invoice2Id,
      'product_id': 2,
      'unit_id': null,
      'quantity': 3,
      'unit_type': 'piece',
      'custom_unit_name': null,
      'price': 150,
      'cost_price': 70,
      'subtotal': 450,
      'profit': 240,
    });

    await db.insert('sale_items', {
      'sale_id': invoice3Id,
      'product_id': 3,
      'unit_id': null,
      'quantity': 1,
      'unit_type': 'piece',
      'custom_unit_name': null,
      'price': 1000,
      'cost_price': 750,
      'subtotal': 1000,
      'profit': 250,
    });

    print('✅ تم إضافة عناصر الفواتير التجريبية!');
  }

  Future<void> _archiveOldInvoices(Database db) async {
    // 1️⃣ خزن IDs الفواتير القديمة (أقدم من سنة)
    final oldSales = await db.query(
      'sales',
      columns: ['id'],
      where: "date < DATE('now', '-1 year')",
    );
    final oldSaleIds = oldSales.map((row) => row['id']).toList();

    if (oldSaleIds.isNotEmpty) {
      final idsString = oldSaleIds.join(',');

      // 2️⃣ أرشيف عناصر الفواتير القديمة
      await db.execute('''
      INSERT INTO sale_items_archive
      SELECT * FROM sale_items
      WHERE sale_id IN ($idsString);
    ''');

      // 3️⃣ أرشيف الفواتير القديمة
      await db.execute('''
      INSERT INTO sales_archive (id, date, total_amount, total_profit, customer_id, payment_type, show_for_tax)
      SELECT id, date, total_amount, total_profit, customer_id, payment_type, show_for_tax
      FROM sales
      WHERE id IN ($idsString);
    ''');

      // 4️⃣ حذف الفواتير القديمة من sales
      await db.execute('''
      DELETE FROM sales
      WHERE id IN ($idsString);
    ''');

      // 5️⃣ حذف عناصر الفواتير القديمة من sale_items
      await db.execute('''
      DELETE FROM sale_items
      WHERE sale_id IN ($idsString);
    ''');
    }

    // 6️⃣ حذف الأرشيف الأقدم من 3 سنوات من sales_archive
    await db.execute('''
    DELETE FROM sales_archive
    WHERE date < DATE('now', '-3 years');
  ''');

    // 7️⃣ حذف عناصر الأرشيف القديمة من sale_items_archive
    await db.execute('''
    DELETE FROM sale_items_archive
    WHERE sale_id NOT IN (SELECT id FROM sales_archive);
  ''');
  }

  Future _onCreate(Database db, int version) async {
    // جدول المنتجات
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        barcode TEXT UNIQUE,
        base_unit TEXT NOT NULL DEFAULT 'piece',
        price REAL NOT NULL,
        quantity REAL NOT NULL,
        cost_price REAL NOT NULL,
        added_date DATETIME DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    // وحدات المنتجات
    await db.execute('''
      CREATE TABLE product_units (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        unit_name TEXT NOT NULL,
        barcode TEXT UNIQUE,
        contain_qty REAL NOT NULL,
        sell_price REAL NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products (id)
      );
    ''');

    // جدول المستخدمين
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        role TEXT NOT NULL,
        google_drive_token TEXT
      );
    ''');

    // إضافة مستخدمين افتراضيين
    await db.insert('users', {
      'name': 'Admin',
      'email': 'admin@gmail.com',
      'password': '123456',
      'role': 'admin',
    });
    await db.insert('users', {
      'name': 'Cashier',
      'email': 'cashier@gmail.com',
      'password': '123456',
      'role': 'cashier',
    });
    await db.insert('users', {
      'name': 'Deyaa',
      'email': 'deyaa@system.com',
      'password': '123456',
      'role': 'tax',
    });

    // جدول الزبائن
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT
      );
    ''');

    // جدول رصيد الزبائن (الدين)
    await db.execute('''
  CREATE TABLE customer_balance (
    customer_id INTEGER PRIMARY KEY,
    balance REAL NOT NULL DEFAULT 0,
    last_updated TEXT,
    FOREIGN KEY (customer_id) REFERENCES customers (id)
  );
''');

    // جدول الدفعات
    await db.execute('''
  CREATE TABLE IF NOT EXISTS transactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id INTEGER NOT NULL,
    amount REAL NOT NULL,
    type TEXT NOT NULL CHECK(type IN ('payment', 'withdrawal')),
    date TEXT NOT NULL,
    note TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers (id)
  );
''');

    // جدول الفواتير
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        total_amount REAL NOT NULL,
        total_profit REAL NOT NULL DEFAULT 0,
        customer_id INTEGER, 
        payment_type TEXT NOT NULL DEFAULT 'cash', 
        show_for_tax INTEGER,
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      );
    ''');

    // جدول عناصر الفاتورة
    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        unit_id INTEGER,
        quantity REAL NOT NULL,
        unit_type TEXT NOT NULL,
        custom_unit_name TEXT,
        price REAL NOT NULL,
        cost_price REAL NOT NULL,
        subtotal REAL NOT NULL,
        profit REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id),
        FOREIGN KEY (product_id) REFERENCES products (id),
        FOREIGN KEY (unit_id) REFERENCES product_units (id)
      );
    ''');

    // أرشيف الفواتير
    await db.execute('''
      CREATE TABLE sales_archive (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        total_amount REAL NOT NULL,
        total_profit REAL NOT NULL DEFAULT 0,
        customer_id INTEGER, 
        payment_type TEXT NOT NULL DEFAULT 'cash', 
        show_for_tax INTEGER
      );
    ''');

    // أرشيف عناصر الفواتير
    await db.execute('''
      CREATE TABLE sale_items_archive (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        unit_id INTEGER,
        quantity REAL NOT NULL,
        unit_type TEXT NOT NULL,
        custom_unit_name TEXT,
        price REAL NOT NULL,
        cost_price REAL NOT NULL,
        subtotal REAL NOT NULL,
        profit REAL NOT NULL
      );
    ''');

    // جدول الموردين
    await db.execute('''
    CREATE TABLE suppliers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
   phone TEXT
);

    ''');

    // جدول فواتير الشراء
    await db.execute('''
  CREATE TABLE purchase_invoices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    supplier_id INTEGER NOT NULL,
    date TEXT NOT NULL,
    total_cost REAL NOT NULL,
    payment_type TEXT NOT NULL DEFAULT 'cash',
    note TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
  );
''');

    // جدول عناصر فاتورة

    await db.execute('''
      CREATE TABLE purchase_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  purchase_id INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  quantity REAL NOT NULL,
  cost_price REAL NOT NULL,
  subtotal REAL NOT NULL,
  FOREIGN KEY (purchase_id) REFERENCES purchase_invoices (id),
  FOREIGN KEY (product_id) REFERENCES products (id)
);

    ''');
    // جدول الإعدادات

    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lowStockThreshold INTEGER,
        marketName TEXT,
        defaultTaxSetting INTEGER NOT NULL DEFAULT 0,
        currency TEXT
      );
    ''');

    await db.insert('settings', {
      'lowStockThreshold': 5,
      'marketName': null,
      'defaultTaxSetting': 0,
      'currency': 'ILS',
    });

    print('✅ تم إنشاء الجداول بنجاح!');
  }
}
