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
    // تهيئة sqflite للـ Windows Desktop
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // اختر مجلد داخل المشروع لتخزين قاعدة البيانات
    String folderPath = join(Directory.current.path, 'data');
    Directory(folderPath).createSync(recursive: true);

    String path = join(folderPath, 'shopmate.db');

    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    // جدول المنتجات
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        barcode TEXT UNIQUE NOT NULL,
        price REAL NOT NULL,
        cost_price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        added_date DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // جدول المستخدمين
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        role TEXT NOT NULL
      )
    ''');

    // إضافة مستخدم افتراضي
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

    // 🧾 جدول الفواتير
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

    // جدول الزبائن

    await db.execute('''
  CREATE TABLE customers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    phone TEXT
);
''');

    await db.execute('''
  CREATE TABLE sale_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sale_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    price REAL NOT NULL,        
    cost_price REAL NOT NULL,   
    subtotal REAL NOT NULL,     
    profit REAL NOT NULL,       
    FOREIGN KEY (sale_id) REFERENCES sales (id),
    FOREIGN KEY (product_id) REFERENCES products (id)
  )
''');

    await db.execute('''
  CREATE TABLE settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    lowStockThreshold INTEGER,
    marketName TEXT,
    defaultTaxSetting INTEGER NOT NULL DEFAULT 0
  )
''');

    await db.insert('settings', {
      'lowStockThreshold': 5,
      'marketName': null,
      'defaultTaxSetting': 0,
    });
  }
}
