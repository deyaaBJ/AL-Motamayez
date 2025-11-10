import 'package:flutter/material.dart';
import 'package:shopmate/models/cart_item.dart';
import 'package:shopmate/models/product.dart';
import 'package:sqflite/sqflite.dart';
import '../db/db_helper.dart';

class ProductProvider with ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  int _page = 0;
  final int _limit = 20;
  bool _hasMore = true;

  List<Product> _products = [];
  List<Product> get products => _products;

  bool get hasMore => _hasMore;
  int get limit => _limit;

  Future<List<Product>> getProducts({bool reset = false}) async {
    final db = await _dbHelper.db;

    if (reset) {
      _page = 0;
      _hasMore = true;
    }

    final result = await db.query(
      'products',
      limit: _limit,
      offset: _page * _limit,
    );

    if (result.length < _limit) _hasMore = false;

    _page++;
    return result.map((e) => Product.fromMap(e)).toList();
  }

  Future<List<Product>> searchProducts(String query) async {
    final db = await _dbHelper.db;
    if (query.trim().isEmpty) return [];

    final result = await db.query(
      'products',
      where: 'LOWER(name) LIKE LOWER(?) OR LOWER(barcode) LIKE LOWER(?)',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );

    return result.map(Product.fromMap).toList();
  }

  Future<List<Product>> searchProductsByBarcode(String query) async {
    final db = await _dbHelper.db;
    if (query.isEmpty) return [];

    final result = await db.query(
      'products',
      where: 'name = ? OR barcode = ?',
      whereArgs: [query, query],
    );

    return result.map((e) => Product.fromMap(e)).toList();
  }

  Future<void> addProduct(Product product) async {
    final db = await _dbHelper.db;
    await db.insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _products.add(product);
    notifyListeners();
  }

  Future<void> updateProduct(Product updatedProduct) async {
    final db = await _dbHelper.db;

    // جلب المنتج الحالي من قاعدة البيانات مباشرة (عشان نضمن أحدث قيمة)
    final result = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [updatedProduct.barcode],
    );

    if (result.isEmpty) return; // المنتج مش موجود

    final existingProduct = Product.fromMap(result.first);

    // نجمع الكمية القديمة مع الجديدة
    final newQuantity = existingProduct.quantity + updatedProduct.quantity;

    // إنشاء نسخة جديدة مع القيم المحدثة
    final productToSave = Product(
      id: existingProduct.id,
      name:
          updatedProduct.name.isNotEmpty
              ? updatedProduct.name
              : existingProduct.name,
      barcode: existingProduct.barcode,
      price:
          updatedProduct.price > 0
              ? updatedProduct.price
              : existingProduct.price,
      costPrice:
          updatedProduct.costPrice > 0
              ? updatedProduct.costPrice
              : existingProduct.costPrice,
      quantity: newQuantity, // ← الجمع هنا
    );

    // تحديث قاعدة البيانات
    await db.update(
      'products',
      productToSave.toMap(),
      where: 'barcode = ?',
      whereArgs: [existingProduct.barcode],
    );

    // تحديث القائمة المحلية إذا موجودة
    final index = _products.indexWhere(
      (p) => p.barcode == updatedProduct.barcode,
    );
    if (index != -1) {
      _products[index] = productToSave;
      notifyListeners();
    }
  }

  Future<void> deleteProduct(String idProduct) async {
    final db = await _dbHelper.db;
    await db.delete('products', where: 'id = ?', whereArgs: [idProduct]);
  }

  Future<void> addSale({
    required List<CartItem> cartItems,
    required double totalAmount,
    String paymentType = 'cash', // افتراضي نقد
    int? customerId, // للزبون عند البيع بالآجل
  }) async {
    final db = await _dbHelper.db;

    await db.transaction((txn) async {
      // 1️⃣ إضافة صف في جدول sales مع دعم credit و customer_id
      final saleId = await txn.insert('sales', {
        'date': DateTime.now().toIso8601String(),
        'total_amount': totalAmount,
        'total_profit': 0.0,
        'customer_id': customerId, // ممكن يكون null إذا نقد
        'payment_type': paymentType, // cash أو credit
      });

      double totalProfit = 0.0;

      // 2️⃣ إضافة العناصر المرتبطة في sale_items
      for (var item in cartItems) {
        final product = item.product;
        final double costPrice = product.costPrice ?? 0.0;
        final double subtotal = product.price * item.quantity;
        final double profit = (product.price - costPrice) * item.quantity;

        totalProfit += profit;

        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': product.id,
          'quantity': item.quantity,
          'price': product.price,
          'cost_price': costPrice,
          'subtotal': subtotal,
          'profit': profit,
        });

        // 3️⃣ خصم الكمية من المخزون
        await txn.rawUpdate(
          '''
        UPDATE products 
        SET quantity = quantity - ?
        WHERE id = ?
        ''',
          [item.quantity, product.id],
        );
      }

      // 4️⃣ تحديث إجمالي الربح في جدول sales
      await txn.update(
        'sales',
        {'total_profit': totalProfit},
        where: 'id = ?',
        whereArgs: [saleId],
      );
    });

    notifyListeners();
  }
}
