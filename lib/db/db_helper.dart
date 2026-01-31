import 'package:path/path.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:developer';

class DBHelper {
  static Database? _db;
  static const int _version = 1; // ⬅️ رجعه ل 1 لأنك ستخلي الداتا وتعيدها

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
    );

    return database;
  }

  Future _onCreate(Database db, int version) async {
    // ========== جدول المنتجات ==========
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        barcode TEXT UNIQUE,
        base_unit TEXT NOT NULL DEFAULT 'piece',
        price REAL NOT NULL,
        quantity REAL NOT NULL,
        cost_price REAL NOT NULL,
        has_expiry INTEGER DEFAULT 1,
        has_expiry_date INTEGER DEFAULT 0,
        active INTEGER DEFAULT 1,
        added_date DATETIME DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    // ========== وحدات المنتجات ==========
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

    // ========== جدول الدفعات (Batches) ==========
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
        active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      );
    ''');

    // ========== جدول المستخدمين ==========
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

    // ========== جدول الزبائن ==========
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT
      );
    ''');

    // ========== جدول رصيد الزبائن ==========
    await db.execute('''
      CREATE TABLE customer_balance (
        customer_id INTEGER PRIMARY KEY,
        balance REAL NOT NULL DEFAULT 0,
        last_updated TEXT,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      );
    ''');

    // ========== جدول الدفعات (المدفوعات) ==========
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

    // ========== جدول الفواتير ==========
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        total_amount REAL NOT NULL,
        total_profit REAL NOT NULL DEFAULT 0,
        customer_id INTEGER, 
        payment_type TEXT NOT NULL DEFAULT 'cash', 
        show_for_tax INTEGER DEFAULT 0,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
      );
    ''');

    // ========== جدول عناصر الفاتورة ==========
    await db.execute('''
      CREATE TABLE sale_items (
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
        profit REAL NOT NULL DEFAULT 0,
        batch_details TEXT,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
        FOREIGN KEY (unit_id) REFERENCES product_units (id) ON DELETE SET NULL
      );
    ''');

    // ========== ⬅️ جدول سجل خصم الدفعات (الجديد) ==========
    await db.execute('''
      CREATE TABLE sale_batch_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        batch_id INTEGER NOT NULL,
        deducted_quantity REAL NOT NULL,
        cost_price REAL NOT NULL,
        expiry_date TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
        FOREIGN KEY (batch_id) REFERENCES product_batches (id) ON DELETE CASCADE
      );
    ''');

    // ========== أرشيف الفواتير ==========
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

    // ========== أرشيف عناصر الفواتير ==========
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
        profit REAL NOT NULL DEFAULT 0,
        batch_details TEXT
      );
    ''');

    // ========== جدول المصاريف ==========
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        payment_type TEXT,
        note TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    // ========== جدول الموردين ==========
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

    // ========== جدول فواتير الشراء ==========
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

    // ========== جدول عناصر فاتورة الشراء ==========
    await db.execute('''
      CREATE TABLE purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        unit_id INTEGER,
        display_quantity REAL,
        quantity REAL NOT NULL,
        cost_price REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (purchase_id) REFERENCES purchase_invoices (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
        FOREIGN KEY (unit_id) REFERENCES product_units (id) ON DELETE SET NULL
      );
    ''');

    // ========== جدول رصيد الموردين ==========
    await db.execute('''
      CREATE TABLE supplier_balance (
        supplier_id INTEGER PRIMARY KEY,
        balance REAL NOT NULL DEFAULT 0,
        last_updated TEXT,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE
      );
    ''');

    // ========== جدول معاملات الموردين ==========
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

    // ========== جدول الإعدادات ==========
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

    // إعدادات افتراضية
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

    log('✅ تم إنشاء جميع الجداول بنجاح!');
  }

  // ========== دوال مساعدة ==========

  Future<void> resetDatabase() async {
    try {
      log('⚠️ بدء عملية إعادة تعيين قاعدة البيانات...');

      if (_db != null) {
        await _db!.close();
        _db = null;
      }

      String folderPath = join(Directory.current.path, 'data');
      String path = join(folderPath, 'motamayez.db');

      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        log('✅ تم حذف ملف قاعدة البيانات القديم');
      }

      _db = await initDb();
      log('🎉 تم إعادة إنشاء قاعدة البيانات بنجاح!');
    } catch (e) {
      log('❌ خطأ في إعادة تعيين قاعدة البيانات: $e');
      rethrow;
    }
  }

  Future<void> checkDatabaseStructure() async {
    try {
      final database = await db;
      log('🔍 التحقق من هيكل قاعدة البيانات...');

      // التحقق من الجداول الرئيسية
      final tables = [
        'products',
        'product_batches',
        'sales',
        'sale_items',
        'sale_batch_log',
        'customers',
        'product_units',
      ];

      for (var table in tables) {
        final result = await database.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [table],
        );

        if (result.isNotEmpty) {
          log('✅ جدول $table موجود');

          // عرض أعمدة الجدول
          final columns = await database.rawQuery('PRAGMA table_info($table)');

          log('   أعمدة جدول $table:');
          for (var column in columns) {
            log('   - ${column['name']} (${column['type']})');
          }
        } else {
          log('❌ جدول $table غير موجود!');
        }
      }

      log('✅ انتهى التحقق من هيكل قاعدة البيانات');
    } catch (e) {
      log('❌ خطأ في التحقق من هيكل قاعدة البيانات: $e');
    }
  }
}
