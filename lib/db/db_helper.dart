import 'package:path/path.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:developer';
import 'package:motamayez/services/password_service.dart';
import 'package:path_provider/path_provider.dart';

class DBHelper {
  static Database? _db;
  static const int _version = 6;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  Future<Database> initDb() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final appDir = await getApplicationDocumentsDirectory();
    String folderPath = join(appDir.path, 'Motamayez', 'data');
    Directory(folderPath).createSync(recursive: true);

    String path = join(folderPath, 'motamayez.db');

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

  // ⬅️ جديد: دالة الترقية بين النسخ
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    log('🔄 ترقية قاعدة البيانات من النسخة $oldVersion إلى $newVersion');

    if (oldVersion < 2) {
      await _upgradeToVersion2(db);
    }

    if (oldVersion < 3) {
      await _upgradeToVersion3(db);
    }

    if (oldVersion < 4) {
      await _upgradeToVersion4(db);
    }

    if (oldVersion < 5) {
      await _upgradeToVersion5(db);
    }

    if (oldVersion < 6) {
      await _upgradeToVersion6(db);
    }
  }

  // ⬅️ جديد: الترقية للنسخة 2 (إضافة user_id)
  Future<void> _upgradeToVersion2(Database db) async {
    try {
      log('⬆️ بدء الترقية للنسخة 2...');

      // التحقق إذا العمود موجود أو لا
      final columns = await db.rawQuery('PRAGMA table_info(sales)');
      bool hasUserId = columns.any((col) => col['name'] == 'user_id');

      if (!hasUserId) {
        // إضافة العمود الجديد
        await db.execute('''
          ALTER TABLE sales 
          ADD COLUMN user_id INTEGER 
          REFERENCES users(id) ON DELETE SET NULL
        ''');
        log('✅ تم إضافة عمود user_id بنجاح');
      } else {
        log('ℹ️ عمود user_id موجود مسبقاً');
      }
    } catch (e) {
      log('❌ خطأ في الترقية للنسخة 2: $e');
      rethrow;
    }
  }

  Future<void> _upgradeToVersion3(Database db) async {
    try {
      log('⬆️ بدء الترقية للنسخة 3...');

      final salesColumns = await db.rawQuery('PRAGMA table_info(sales)');
      final hasPaidAmount = salesColumns.any(
        (col) => col['name'] == 'paid_amount',
      );
      final hasRemainingAmount = salesColumns.any(
        (col) => col['name'] == 'remaining_amount',
      );

      if (!hasPaidAmount) {
        await db.execute(
          'ALTER TABLE sales ADD COLUMN paid_amount REAL NOT NULL DEFAULT 0',
        );
      }

      if (!hasRemainingAmount) {
        await db.execute(
          'ALTER TABLE sales ADD COLUMN remaining_amount REAL NOT NULL DEFAULT 0',
        );
      }

      await db.execute('''
        UPDATE sales
        SET
          paid_amount = CASE
            WHEN payment_type = 'cash' THEN total_amount
            ELSE COALESCE(paid_amount, 0)
          END,
          remaining_amount = CASE
            WHEN payment_type = 'credit' THEN total_amount
            ELSE 0
          END
        WHERE COALESCE(paid_amount, 0) = 0 AND COALESCE(remaining_amount, 0) = 0
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS sale_payment_allocations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          transaction_id INTEGER NOT NULL,
          sale_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE,
          FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
        )
      ''');

      log('✅ تمت ترقية تتبع سداد فواتير البيع');
    } catch (e) {
      log('❌ خطأ في الترقية للنسخة 3: $e');
      rethrow;
    }
  }

  Future<void> _upgradeToVersion4(Database db) async {
    try {
      log('⬆️ بدء الترقية للنسخة 4...');

      final salesColumns = await db.rawQuery('PRAGMA table_info(sales)');
      final hasUserId = salesColumns.any((col) => col['name'] == 'user_id');

      if (!hasUserId) {
        await db.execute('''
          ALTER TABLE sales
          ADD COLUMN user_id INTEGER
          REFERENCES users(id) ON DELETE SET NULL
        ''');
      }

      log('✅ تم التحقق من عمود user_id في جدول sales');
    } catch (e) {
      log('❌ خطأ في الترقية للنسخة 4: $e');
      rethrow;
    }
  }

  Future<void> _upgradeToVersion5(Database db) async {
    await _migrateLegacyPasswords(db);
    await _createIndexes(db);
  }

  Future<void> _upgradeToVersion6(Database db) async {
    await _upgradeArchiveSchema(db);
    await _createIndexes(db);
    await archiveHistoricalSales(database: db);
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
        paid_amount REAL NOT NULL DEFAULT 0,
        remaining_amount REAL NOT NULL DEFAULT 0,
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
        paid_amount REAL NOT NULL DEFAULT 0,
        remaining_amount REAL NOT NULL DEFAULT 0,
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
        type TEXT NOT NULL CHECK (type IN ('purchase', 'payment','return')),
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
        logerPort INTEGER,
        logerIp TEXT,
        paperSize TEXT,
        numberOfCopies INTEGER DEFAULT 5
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
      'name': 'Cashier',
      'email': 'cashier@gmail.com',
      'password': defaultPasswordHash,
      'role': 'cashier',
    });
    await db.insert('users', {
      'name': 'Deyaa',
      'email': 'deyaa@system.com',
      'password': defaultPasswordHash,
      'role': 'tax',
    });
  }

  Future<void> _migrateLegacyPasswords(Database db) async {
    final users = await db.query('users', columns: ['id', 'password']);
    for (final user in users) {
      final storedPassword = user['password']?.toString() ?? '';
      if (!PasswordService.isLegacyPlaintext(storedPassword)) {
        continue;
      }

      await db.update(
        'users',
        {'password': PasswordService.hashPassword(storedPassword)},
        where: 'id = ?',
        whereArgs: [user['id']],
      );
    }
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
  }

  Future<void> _upgradeArchiveSchema(Database db) async {
    final salesArchiveColumns = await db.rawQuery(
      'PRAGMA table_info(sales_archive)',
    );
    final saleItemsArchiveColumns = await db.rawQuery(
      'PRAGMA table_info(sale_items_archive)',
    );

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
          show_for_tax INTEGER,
          user_id INTEGER,
          archived_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
    } else {
      await _addColumnIfMissing(
        db,
        tableName: 'sales_archive',
        columns: salesArchiveColumns,
        columnName: 'paid_amount',
        statement:
            'ALTER TABLE sales_archive ADD COLUMN paid_amount REAL NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        tableName: 'sales_archive',
        columns: salesArchiveColumns,
        columnName: 'remaining_amount',
        statement:
            'ALTER TABLE sales_archive ADD COLUMN remaining_amount REAL NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        tableName: 'sales_archive',
        columns: salesArchiveColumns,
        columnName: 'user_id',
        statement: 'ALTER TABLE sales_archive ADD COLUMN user_id INTEGER',
      );
      await _addColumnIfMissing(
        db,
        tableName: 'sales_archive',
        columns: salesArchiveColumns,
        columnName: 'archived_at',
        statement:
            'ALTER TABLE sales_archive ADD COLUMN archived_at TEXT DEFAULT CURRENT_TIMESTAMP',
      );
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
  }

  Future<void> _addColumnIfMissing(
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
    }
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
      final placeholders = List.filled(ids.length, '?').join(',');

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
          show_for_tax,
          user_id,
          CURRENT_TIMESTAMP
        FROM sales
        WHERE id IN ($placeholders)
        ''', ids);

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
        ''', ids);

      await txn.delete(
        'sale_batch_log',
        where: 'sale_id IN ($placeholders)',
        whereArgs: ids,
      );
      await txn.delete(
        'sale_items',
        where: 'sale_id IN ($placeholders)',
        whereArgs: ids,
      );
      await txn.delete('sales', where: 'id IN ($placeholders)', whereArgs: ids);

      archivedSalesCount = ids.length;
    });

    if (archivedSalesCount > 0) {
      log('Archived $archivedSalesCount historical sales records');
    }

    return archivedSalesCount;
  }

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
