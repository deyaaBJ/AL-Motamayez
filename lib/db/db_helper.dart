import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:developer';
import 'package:motamayez/services/password_service.dart';

class DBHelper {
  static Database? _db;
  // ⬅️ تم رفع رقم النسخة لأننا أضفنا عمود debt_added_in_period لجدول sales_archive
  static const int _version = 15;

  // SQLite لديها حد أقصى افتراضي لعدد الـ bound parameters بالاستعلام الواحد
  // (عادة 999). نقسم القوائم الطويلة لدفعات أصغر لتفادي فشل الاستعلام بالكامل.
  static const int _sqliteMaxVariables = 500;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  Future<Database> initDb() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // ✅ إصلاح مشكلة الصلاحيات: لا نعتمد على working directory (Directory.current)
    // لأنه قد يكون داخل مجلد نظام محمي مثل C:\Program Files عند التثبيت،
    // ما يسبب Access Denied. نستخدم مجلد بيانات التطبيق الرسمي المخصص للكتابة.
    String folderPath = await _resolveDataFolderPath();

    // إنشاء المجلد إذا لم يكن موجوداً
    await Directory(folderPath).create(recursive: true);

    String path = join(folderPath, 'motamayez.db');
    debugPrint('📂 Database path: $path');
    debugPrint('📌 Active DB file will be created/opened here: $path');
    print('📂 Database path: $path');
    print('📌 Active DB file will be created/opened here: $path');

    Database database = await openDatabase(
      path,
      version: _version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    await _upgradeArchiveSchema(database);
    await archiveHistoricalSales(database: database);

    return database;
  }

  /// يحدد مجلد بيانات التطبيق الصحيح والقابل للكتابة على كل منصة.
  /// - Desktop (Windows/Linux/macOS): مجلد بيانات التطبيق الخاص بالمستخدم
  ///   (مثال Windows: C:\Users\<user>\AppData\Roaming\<app>), وهو دائماً قابل للكتابة
  ///   بعكس مجلد التثبيت (Program Files) الذي قد يكون محمياً.
  /// - في وضع التطوير (لا يوجد getApplicationSupportDirectory متاح لسبب ما)
  ///   نرجع لمجلد المشروع كخطة بديلة.
  Future<String> _resolveDataFolderPath() async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      return join(supportDir.path, 'data');
    } catch (e) {
      log('⚠️ تعذر الوصول لمجلد بيانات التطبيق، سيتم استخدام مجلد المشروع: $e');
      return join(Directory.current.path, 'data');
    }
  }

  Future<String> getDatabasePath() async {
    final folderPath = await _resolveDataFolderPath();
    return join(folderPath, 'motamayez.db');
  }

  // تحديث دالة resetDatabase لتستخدم نفس المسار الجديد
  Future<void> resetDatabase() async {
    try {
      log('⚠️ بدء عملية إعادة تعيين قاعدة البيانات...');

      if (_db != null) {
        await _db!.close();
        _db = null;
      }

      String folderPath = await _resolveDataFolderPath();
      String path = join(folderPath, 'motamayez.db');

      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        log('✅ تم حذف ملف قاعدة البيانات القديم من مجلد data');
      }

      _db = await initDb();
      log('🎉 تم إعادة إنشاء قاعدة البيانات بنجاح!');
    } catch (e) {
      log('❌ خطأ في إعادة تعيين قاعدة البيانات: $e');
      rethrow;
    }
  }

  // ⬅️ دالة الترقية بين النسخ
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    log('🔄 ترقية قاعدة البيانات من النسخة $oldVersion إلى $newVersion');

    if (oldVersion < 14) {
      await _upgradeToVersion14(db);
    }
    if (oldVersion < 15) {
      await _upgradeToVersion15(db);
    }
  }

  Future<void> _upgradeToVersion14(Database db) async {
    try {
      log('Starting upgrade to version 14...');

      final settingsColumns = await db.rawQuery('PRAGMA table_info(settings)');

      await _addColumnIfMissing(
        db,
        tableName: 'settings',
        columns: settingsColumns,
        columnName: 'nearExpiryAlertDays',
        statement:
            'ALTER TABLE settings ADD COLUMN nearExpiryAlertDays INTEGER NOT NULL DEFAULT 7',
      );

      await db.execute('''
        UPDATE settings
        SET nearExpiryAlertDays = COALESCE(nearExpiryAlertDays, 7)
      ''');

      log('Completed upgrade to version 14');
    } catch (e) {
      log('Upgrade to version 14 failed: $e');
      rethrow;
    }
  }

  // ✅ جديد: ترقية مخصصة لإضافة عمود debt_added_in_period لجدول sales_archive
  Future<void> _upgradeToVersion15(Database db) async {
    try {
      log('Starting upgrade to version 15...');

      final archiveColumns = await db.rawQuery(
        'PRAGMA table_info(sales_archive)',
      );

      if (archiveColumns.isNotEmpty) {
        await _addColumnIfMissing(
          db,
          tableName: 'sales_archive',
          columns: archiveColumns,
          columnName: 'debt_added_in_period',
          statement:
              'ALTER TABLE sales_archive ADD COLUMN debt_added_in_period REAL NOT NULL DEFAULT 0',
        );
      }

      log('Completed upgrade to version 15');
    } catch (e) {
      log('Upgrade to version 15 failed: $e');
      rethrow;
    }
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
        offer_price REAL,
        offer_start_date TEXT,
        offer_end_date TEXT,
        offer_enabled INTEGER NOT NULL DEFAULT 0,
        quantity REAL NOT NULL,
        cost_price REAL NOT NULL,
        low_stock_threshold INTEGER,
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
        parent_unit_id INTEGER,
        barcode TEXT UNIQUE,
        contain_qty REAL NOT NULL,
        multiplier_numerator INTEGER NOT NULL DEFAULT 1,
        multiplier_denominator INTEGER NOT NULL DEFAULT 1,
        sell_price REAL NOT NULL,
        offer_price REAL,
        offer_start_date TEXT,
        offer_end_date TEXT,
        offer_enabled INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
        FOREIGN KEY (parent_unit_id) REFERENCES product_units (id) ON DELETE SET NULL
      );
    ''');

    // ========== جدول الواردات (Batches) ==========
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
    await _seedDefaultUsers(db);

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

    // ========== جدول الواردات (المدفوعات) ==========
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
        paid_amount REAL NOT NULL DEFAULT 0,
        remaining_amount REAL NOT NULL DEFAULT 0,
        debt_added_in_period REAL NOT NULL DEFAULT 0,
        show_for_tax INTEGER DEFAULT 0,
        user_id INTEGER,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE sale_payment_allocations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        sale_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
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

    // ========== جدول سجل خصم الواردات ==========
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
    // ✅ تمت إضافة debt_added_in_period هنا حتى تتطابق بنية الجدول مع sales تماماً
    await db.execute('''
      CREATE TABLE sales_archive (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        total_amount REAL NOT NULL,
        total_profit REAL NOT NULL DEFAULT 0,
        customer_id INTEGER, 
        payment_type TEXT NOT NULL DEFAULT 'cash', 
        paid_amount REAL NOT NULL DEFAULT 0,
        remaining_amount REAL NOT NULL DEFAULT 0,
        debt_added_in_period REAL NOT NULL DEFAULT 0,
        show_for_tax INTEGER,
        user_id INTEGER,
        archived_at TEXT DEFAULT CURRENT_TIMESTAMP
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
        type TEXT NOT NULL CHECK (type IN ('purchase', 'payment', 'return', 'collection')),
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE,
        FOREIGN KEY (purchase_invoice_id) REFERENCES purchase_invoices (id) ON DELETE SET NULL
      );
    ''');

    await db.execute('''
        CREATE TABLE opening_balances (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          movement_type TEXT NOT NULL DEFAULT 'opening_balance',
          date TEXT NOT NULL,
          note TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        );
      ''');

    await db.execute('''
      CREATE TABLE opening_balance_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        opening_balance_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        cost_price REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (opening_balance_id) REFERENCES opening_balances (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
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
        logerPort INTEGER,
        logerIp TEXT,
        paperSize TEXT,
        numberOfCopies INTEGER DEFAULT 5,
        nearExpiryAlertDays INTEGER NOT NULL DEFAULT 7
      );
    ''');

    // إعدادات افتراضية
    await db.insert('settings', {
      'lowStockThreshold': 5,
      'marketName': null,
      'defaultTaxSetting': 0,
      'currency': 'ILS',
      'logerPort': '9100',
      'logerIp': null,
      'paperSize': '58mm',
      'numberOfCopies': 5,
      'nearExpiryAlertDays': 7,
    });

    await _createIndexes(db);

    log('✅ تم إنشاء جميع الجداول بنجاح!');
  }

  // ========== دوال مساعدة ==========
  Future<void> _seedDefaultUsers(Database db) async {
    final defaultPasswordHash = PasswordService.hashPassword('123456');
    await db.insert('users', {
      'name': 'Admin',
      'email': 'admin@gmail.com',
      'password': defaultPasswordHash,
      'role': 'admin',
    });
    await db.insert('users', {
      'name': 'tax',
      'email': 'tax@system.com',
      'password': defaultPasswordHash,
      'role': 'tax',
    });
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(date DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_customer_id ON sales(customer_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_payment_type ON sales(payment_type)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_tax_date ON sales(show_for_tax, date DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_customer_date ON sales(customer_id, date DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_archive_date ON sales_archive(date DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_archive_customer_date ON sales_archive(customer_id, date DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_archive_payment_type ON sales_archive(payment_type)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_archive_archived_at ON sales_archive(archived_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_customer_date ON transactions(customer_id, date DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(sale_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sale_items_archive_sale_id ON sale_items_archive(sale_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sale_allocations_sale_id ON sale_payment_allocations(sale_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_product_units_product_id ON product_units(product_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_product_batches_product_id ON product_batches(product_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_invoices_supplier_date ON purchase_invoices(supplier_id, date DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_supplier_transactions_supplier_date ON supplier_transactions(supplier_id, date DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_opening_balances_date ON opening_balances(date DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_opening_balance_items_balance_id ON opening_balance_items(opening_balance_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_opening_balance_items_product_id ON opening_balance_items(product_id)',
    );
  }

  /// ✅ إصلاح مشكلة بطء الإقلاع: كانت UPDATE sales_archive تعمل بكل مرة يفتح
  /// فيها التطبيق بغض النظر عن وجود تغيير فعلي، ما يسبب مسح كامل للجدول
  /// (Full Table Scan) في كل تشغيل. الآن: يتم تشغيل الـ backfill فقط إذا تمت
  /// إضافة أعمدة جديدة فعلاً (أول مرة بعد الترقية)، وإلا يتم تجاهله بالكامل.
  Future<void> _upgradeArchiveSchema(Database db) async {
    final salesArchiveColumns = await db.rawQuery(
      'PRAGMA table_info(sales_archive)',
    );
    final saleItemsArchiveColumns = await db.rawQuery(
      'PRAGMA table_info(sale_items_archive)',
    );

    bool needsBackfill = false;

    if (salesArchiveColumns.isEmpty) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sales_archive (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          total_amount REAL NOT NULL,
          total_profit REAL NOT NULL DEFAULT 0,
          customer_id INTEGER,
          payment_type TEXT NOT NULL DEFAULT 'cash',
          paid_amount REAL NOT NULL DEFAULT 0,
          remaining_amount REAL NOT NULL DEFAULT 0,
          debt_added_in_period REAL NOT NULL DEFAULT 0,
          show_for_tax INTEGER,
          user_id INTEGER,
          archived_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      // جدول جديد بالكامل، لا حاجة لـ backfill لأنه فاضي
    } else {
      final addedPaid = await _addColumnIfMissing(
        db,
        tableName: 'sales_archive',
        columns: salesArchiveColumns,
        columnName: 'paid_amount',
        statement:
            'ALTER TABLE sales_archive ADD COLUMN paid_amount REAL NOT NULL DEFAULT 0',
      );
      final addedRemaining = await _addColumnIfMissing(
        db,
        tableName: 'sales_archive',
        columns: salesArchiveColumns,
        columnName: 'remaining_amount',
        statement:
            'ALTER TABLE sales_archive ADD COLUMN remaining_amount REAL NOT NULL DEFAULT 0',
      );
      final addedUserId = await _addColumnIfMissing(
        db,
        tableName: 'sales_archive',
        columns: salesArchiveColumns,
        columnName: 'user_id',
        statement: 'ALTER TABLE sales_archive ADD COLUMN user_id INTEGER',
      );
      final addedArchivedAt = await _addColumnIfMissing(
        db,
        tableName: 'sales_archive',
        columns: salesArchiveColumns,
        columnName: 'archived_at',
        statement:
            'ALTER TABLE sales_archive ADD COLUMN archived_at TEXT DEFAULT CURRENT_TIMESTAMP',
      );
      final addedDebt = await _addColumnIfMissing(
        db,
        tableName: 'sales_archive',
        columns: salesArchiveColumns,
        columnName: 'debt_added_in_period',
        statement:
            'ALTER TABLE sales_archive ADD COLUMN debt_added_in_period REAL NOT NULL DEFAULT 0',
      );

      needsBackfill =
          addedPaid ||
          addedRemaining ||
          addedUserId ||
          addedArchivedAt ||
          addedDebt;
    }

    if (saleItemsArchiveColumns.isEmpty) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sale_items_archive (
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
        )
      ''');
    }

    // ⬅️ هذا الاستعلام الثقيل الآن يعمل فقط لما فعلاً تمت إضافة أعمدة جديدة
    // (أي مرة واحدة عند الترقية)، وليس بكل فتح للتطبيق.
    if (needsBackfill) {
      log('🔧 تنفيذ backfill لجدول sales_archive بعد إضافة أعمدة جديدة...');
      await db.execute('''
        UPDATE sales_archive
        SET
          paid_amount = CASE
            WHEN payment_type = 'cash' AND COALESCE(paid_amount, 0) = 0 THEN total_amount
            ELSE COALESCE(paid_amount, total_amount - COALESCE(remaining_amount, 0))
          END,
          remaining_amount = CASE
            WHEN payment_type = 'credit' THEN COALESCE(remaining_amount, 0)
            ELSE 0
          END,
          archived_at = COALESCE(archived_at, CURRENT_TIMESTAMP)
      ''');
      log('✅ اكتمل backfill جدول sales_archive');
    }
  }

  /// يرجع true إذا تمت إضافة العمود فعلاً (أي كان مفقوداً)، و false إذا كان موجوداً أصلاً.
  Future<bool> _addColumnIfMissing(
    Database db, {
    required String tableName,
    required List<Map<String, Object?>> columns,
    required String columnName,
    required String statement,
  }) async {
    final hasColumn = columns.any((column) => column['name'] == columnName);
    if (!hasColumn) {
      log('Adding missing column $columnName to $tableName');
      await db.execute(statement);
      return true;
    }
    return false;
  }

  /// يقسم قائمة معرفات طويلة إلى دفعات أصغر لتفادي تجاوز حد SQLite
  /// لعدد الـ bound parameters بالاستعلام الواحد (خصوصاً بأول أرشفة لبيانات قديمة كثيرة).
  List<List<int>> _chunkIds(List<int> ids, int chunkSize) {
    final chunks = <List<int>>[];
    for (var i = 0; i < ids.length; i += chunkSize) {
      chunks.add(
        ids.sublist(i, i + chunkSize > ids.length ? ids.length : i + chunkSize),
      );
    }
    return chunks;
  }

  Future<int> archiveHistoricalSales({Database? database}) async {
    final db = database ?? await this.db;
    // ✅ محاسبي دقيق: أرشيف فواتير أقدم من 365 يوم + بدون دين
    int archivedSalesCount = 0;

    await db.transaction((txn) async {
      final eligibleSales = await txn.rawQuery('''
        SELECT id
        FROM sales
        WHERE julianday('now') - julianday(date) >= 365
          AND (
            payment_type != 'credit'
            OR COALESCE(remaining_amount, total_amount) <= 0.0001
          )
      ''');

      if (eligibleSales.isEmpty) {
        return;
      }

      final ids = eligibleSales.map((row) => row['id'] as int).toList();

      // ✅ إصلاح مشكلة تجاوز حد الـ parameters: نقسم المعرفات لدفعات
      // بدل تمريرها كلها دفعة واحدة باستعلام قد يفشل مع أعداد كبيرة.
      final chunks = _chunkIds(ids, _sqliteMaxVariables);

      for (final chunk in chunks) {
        final placeholders = List.filled(chunk.length, '?').join(',');

        await txn.rawInsert('''
          INSERT OR REPLACE INTO sales_archive (
            id,
            date,
            total_amount,
            total_profit,
            customer_id,
            payment_type,
            paid_amount,
            remaining_amount,
            debt_added_in_period,
            show_for_tax,
            user_id,
            archived_at
          )
          SELECT
            id,
            date,
            total_amount,
            total_profit,
            customer_id,
            payment_type,
            COALESCE(paid_amount, CASE WHEN payment_type = 'cash' THEN total_amount ELSE 0 END),
            COALESCE(remaining_amount, CASE WHEN payment_type = 'credit' THEN total_amount ELSE 0 END),
            COALESCE(debt_added_in_period, 0),
            show_for_tax,
            user_id,
            CURRENT_TIMESTAMP
          FROM sales
          WHERE id IN ($placeholders)
          ''', chunk);

        await txn.rawInsert('''
          INSERT OR REPLACE INTO sale_items_archive (
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
            profit,
            batch_details
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
            profit,
            batch_details
          FROM sale_items
          WHERE sale_id IN ($placeholders)
          ''', chunk);

        await txn.delete(
          'sale_batch_log',
          where: 'sale_id IN ($placeholders)',
          whereArgs: chunk,
        );
        await txn.delete(
          'sale_items',
          where: 'sale_id IN ($placeholders)',
          whereArgs: chunk,
        );
        await txn.delete(
          'sales',
          where: 'id IN ($placeholders)',
          whereArgs: chunk,
        );
      }

      archivedSalesCount = ids.length;
    });

    if (archivedSalesCount > 0) {
      log('Archived $archivedSalesCount historical sales records');
    }

    return archivedSalesCount;
  }

  Future<void> checkDatabaseStructure() async {
    try {
      final database = await db;
      log('🔍 التحقق من هيكل قاعدة البيانات...');

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

  /// 🔧 إصلاح الواردات بدون تاريخ انتهاء التي لديها active = 0
  Future<int> fixInactiveNoExpiryBatches() async {
    try {
      final database = await db;

      final result = await database.rawUpdate('''
        UPDATE product_batches 
        SET active = 1
        WHERE active = 0
        AND (expiry_date IS NULL OR expiry_date = '' OR expiry_date = '2099-12-31')
        AND remaining_quantity > 0
      ''');

      log('✅ تم إصلاح $result دفعة بدون تاريخ انتهاء');
      return result;
    } catch (e) {
      log('❌ خطأ في إصلاح البيانات: $e');
      return 0;
    }
  }

  /// 📊 الحصول على إحصائيات الواردات
  Future<Map<String, int>> getBatchStats() async {
    try {
      final database = await db;

      final totalResult = await database.rawQuery('''
        SELECT COUNT(*) as count FROM product_batches WHERE active = 1
      ''');
      final totalActive = (totalResult.first['count'] as int?) ?? 0;

      final noExpiryResult = await database.rawQuery('''
        SELECT COUNT(*) as count FROM product_batches 
        WHERE active = 1 
        AND (expiry_date IS NULL OR expiry_date = '' OR expiry_date = '2099-12-31')
      ''');
      final noExpiryActive = (noExpiryResult.first['count'] as int?) ?? 0;

      final noExpiryInactiveResult = await database.rawQuery('''
        SELECT COUNT(*) as count FROM product_batches 
        WHERE active = 0 
        AND (expiry_date IS NULL OR expiry_date = '' OR expiry_date = '2099-12-31')
        AND remaining_quantity > 0
      ''');
      final noExpiryInactive =
          (noExpiryInactiveResult.first['count'] as int?) ?? 0;

      return {
        'total_active': totalActive,
        'no_expiry_active': noExpiryActive,
        'no_expiry_inactive': noExpiryInactive,
      };
    } catch (e) {
      log('❌ خطأ في جلب إحصائيات الواردات: $e');
      return {
        'total_active': 0,
        'no_expiry_active': 0,
        'no_expiry_inactive': 0,
      };
    }
  }
}
