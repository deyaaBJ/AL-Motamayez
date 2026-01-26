import 'package:path/path.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:developer';

class DBHelper {
  static Database? _db;
  static const int _version = 3; // زيادة الرقم لتطبيق التحديثات

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  Future<Database> initDb() async {
    // تهيئة sqflite للويب أو سطح المكتب
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String folderPath = join(Directory.current.path, 'data');
    Directory(folderPath).createSync(recursive: true);

    String path = join(folderPath, 'motamayez.db');

    Database database = await openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    await _archiveOldInvoices(database);
    return database;
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // إضافة الفهارس في الترقية
      await _createIndexes(db);
    }
    if (oldVersion < 3) {
      // أي تحديثات أخرى
    }
  }

  // دالة لإنشاء الفهارس
  Future<void> _createIndexes(Database db) async {
    try {
      // فهارس للموردين
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers (name)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_suppliers_phone ON suppliers (phone)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_suppliers_created ON suppliers (created_at)',
      );

      // فهارس للمنتجات
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_name ON products (name)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_barcode ON products (barcode)',
      );

      // فهارس للزبائن
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_name ON customers (name)',
      );

      // فهارس للفواتير
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_date ON sales (date)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_customer ON sales (customer_id)',
      );

      // فهارس لفواتير الشراء
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_purchase_invoices_date ON purchase_invoices (date)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_purchase_invoices_supplier ON purchase_invoices (supplier_id)',
      );

      // فهارس للأرصدة
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_supplier_balance_supplier ON supplier_balance (supplier_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customer_balance_customer ON customer_balance (customer_id)',
      );

      // فهارس للمعاملات
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_supplier_transactions_supplier ON supplier_transactions (supplier_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transactions_customer ON transactions (customer_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_supplier_transactions_date ON supplier_transactions (date)',
      );

      log('✅ تم إنشاء الفهارس بنجاح!');
    } catch (e) {
      log('❌ خطأ في إنشاء الفهارس: $e');
    }
  }

  Future<void> _archiveOldInvoices(Database db) async {
    try {
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
        INSERT INTO sale_items_archive (
  id,
  sale_id,
  item_type,
  product_id,
  unit_id,
  quantity,
  unit_type,
  custom_unit_name,
  price,
  cost_price,
  subtotal,
  profit
)
SELECT
  id,
  sale_id,
  item_type,
  product_id,
  unit_id,
  quantity,
  unit_type,
  custom_unit_name,
  price,
  cost_price,
  subtotal,
  profit
FROM sale_items
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
    } catch (e) {
      log('❌ خطأ في أرشفة الفواتير: $e');
    }
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
        has_expiry BOOLEAN DEFAULT 1,
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
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE expenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,            -- كهرباء، ماء، صيانة...
      amount REAL NOT NULL,
      date TEXT NOT NULL,
      payment_type TEXT,             -- cash / transfer / check
      note TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );
        ''');

    await db.execute('''

  CREATE TABLE product_batches (

    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL,
    purchase_item_id INTEGER, 
    quantity REAL NOT NULL,
    remaining_quantity REAL NOT NULL,
    cost_price REAL NOT NULL,
    production_date TEXT,   
    expiry_date TEXT NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
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
      phone TEXT
      )
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
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
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
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
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
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
      );
    ''');

    // جدول عناصر الفاتورة
    await db.execute('''
CREATE TABLE sale_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sale_id INTEGER NOT NULL,

  item_type TEXT NOT NULL DEFAULT 'product', -- product / service

  product_id INTEGER,        -- NULL للخدمة
  unit_id INTEGER,

  quantity REAL NOT NULL DEFAULT 1,
  unit_type TEXT NOT NULL,
  custom_unit_name TEXT,

  price REAL NOT NULL,
  cost_price REAL NOT NULL DEFAULT 0,
  subtotal REAL NOT NULL,
  profit REAL NOT NULL DEFAULT 0,

  FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
  FOREIGN KEY (unit_id) REFERENCES product_units (id) ON DELETE SET NULL
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

  item_type TEXT NOT NULL DEFAULT 'product',

  product_id INTEGER,
  unit_id INTEGER,

  quantity REAL NOT NULL DEFAULT 1,
  unit_type TEXT NOT NULL,
  custom_unit_name TEXT,

  price REAL NOT NULL,
  cost_price REAL NOT NULL DEFAULT 0,
  subtotal REAL NOT NULL,
  profit REAL NOT NULL DEFAULT 0
);

    ''');

    // جدول الموردين
    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        notes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    // جدول فواتير الشراء
    await db.execute('''
      CREATE TABLE purchase_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        total_cost REAL NOT NULL,              
        paid_amount REAL NOT NULL DEFAULT 0,   
        remaining_amount REAL NOT NULL DEFAULT 0,
        payment_type TEXT NOT NULL CHECK (
          payment_type IN ('cash', 'credit', 'partial')
        ),
        note TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE
      );
    ''');

    // جدول عناصر فاتورة الشراء
    await db.execute('''
      CREATE TABLE purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        cost_price REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (purchase_id) REFERENCES purchase_invoices (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      );
    ''');

    // جدول رصيد الموردين
    await db.execute('''
      CREATE TABLE supplier_balance (
        supplier_id INTEGER PRIMARY KEY,
        balance REAL NOT NULL DEFAULT 0,
        last_updated TEXT,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE
      );
    ''');

    // جدول معاملات الموردين
    await db.execute('''
      CREATE TABLE supplier_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL,
        purchase_invoice_id INTEGER,
        amount REAL NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('purchase', 'payment')),
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE,
        FOREIGN KEY (purchase_invoice_id) REFERENCES purchase_invoices (id) ON DELETE SET NULL
      );
    ''');

    // جدول الإعدادات
    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lowStockThreshold INTEGER,
        marketName TEXT,
        defaultTaxSetting INTEGER NOT NULL DEFAULT 0,
        currency TEXT,
        printerPort INTEGER,
        printerIp TEXT,
        paperSize TEXT,
        numberOfCopies INTEGER DEFAULT 1
      );
    ''');

    await db.insert('settings', {
      'lowStockThreshold': 5,
      'marketName': null,
      'defaultTaxSetting': 0,
      'currency': 'ILS',
      'printerPort': '9100',
      'printerIp': null,
      'paperSize': '58mm',
      'numberOfCopies': 1,
    });

    // إنشاء الفهارس بعد إنشاء الجداول
    await _createIndexes(db);
  }

  // دالة مساعدة للتحقق من وجود فهرس
  Future<bool> indexExists(Database db, String indexName) async {
    try {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name=?",
        [indexName],
      );
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
