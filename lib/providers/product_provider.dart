import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:motamayez/models/cart_item.dart';
import 'package:motamayez/models/product.dart';
import 'package:motamayez/models/productFilter.dart';
import 'package:motamayez/models/product_unit.dart';
import 'package:motamayez/models/sale.dart';
import 'package:motamayez/models/sale_item.dart';
import 'package:motamayez/utils/unit_translator.dart';
import 'package:sqflite/sqflite.dart';
import '../db/db_helper.dart';
import 'dart:developer';

class ProductProvider with ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  // ========== متغيرات المنتجات ==========
  int _page = 0;
  final int _limit = 20;
  bool _hasMore = true;

  List<Product> _products = [];
  List<Product> get products => _products;

  int _totalProducts = 0;
  int get totalProducts => _totalProducts;

  bool get hasMore => _hasMore;
  int get currentPage => _page;

  ProductFilter? _currentActiveFilter;

  // ========== متغيرات الفواتير ==========
  List<Sale> _allSales = [];
  List<Sale> get allSales => _allSales;

  List<Sale> _displayedSales = [];
  List<Sale> get displayedSales => _displayedSales;

  DateTime? _currentStartDate;
  DateTime? _currentEndDate;

  int lowStockCount = 0;
  int outOfStockCount = 0;

  // ========== دوال المنتجات ==========

  void resetPagination() {
    _page = 0;
    _hasMore = true;
    _products.clear();
    notifyListeners();
  }

  Future<void> loadTotalProducts() async {
    final db = await _dbHelper.db;
    final res = await db.rawQuery("SELECT COUNT(*) as count FROM products");
    _totalProducts = res.first['count'] as int;
    notifyListeners();
  }

  Future<void> loadStockCounts(int threshold) async {
    lowStockCount = await loadLowStockProductsCount(threshold);
    outOfStockCount = await loadOutOfStockProductsCount();
    notifyListeners();
  }

  Future<int> loadLowStockProductsCount(int lowStockThreshold) async {
    final db = await _dbHelper.db;
    final res = await db.rawQuery(
      "SELECT COUNT(*) as count FROM products WHERE quantity <= ? AND quantity > 0",
      [lowStockThreshold],
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<int> loadOutOfStockProductsCount() async {
    final db = await _dbHelper.db;
    final res = await db.rawQuery(
      "SELECT COUNT(*) as count FROM products WHERE quantity <= 0",
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<List<Product>> loadProducts({bool reset = false, bool? active}) async {
    if (!reset && !_hasMore) return [];

    if (reset) {
      resetPagination();
    }

    final db = await _dbHelper.db;

    try {
      String whereClause = '';
      List<Object?> whereArgs = [];

      if (active != null) {
        whereClause = 'active = ?';
        whereArgs.add(active ? 1 : 0);
      }

      final result = await db.query(
        'products',
        where: whereClause.isNotEmpty ? whereClause : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        limit: _limit,
        offset: _page * _limit,
        orderBy: 'id DESC',
      );

      if (result.isEmpty) {
        _hasMore = false;
        return [];
      }

      final newProducts =
          result.map((map) {
            try {
              return Product(
                id: map['id'] as int?,
                name: (map['name'] ?? '') as String,
                barcode: map['barcode'] as String?,
                baseUnit: (map['base_unit'] ?? 'piece') as String,
                price: ((map['price'] ?? 0) as num).toDouble(),
                quantity: ((map['quantity'] ?? 0) as num).toDouble(),
                costPrice: ((map['cost_price'] ?? 0) as num).toDouble(),
                addedDate: map['added_date'] as String?,
                hasExpiryDate: (map['has_expiry_date'] as int?) == 1,
                active: (map['active'] as int?) != 0,
              );
            } catch (e) {
              log('Error parsing product: $e, map: $map');
              return Product(
                id: 0,
                name: 'Error',
                baseUnit: 'piece',
                price: 0,
                quantity: 0,
                costPrice: 0,
              );
            }
          }).toList();

      _page++;
      if (newProducts.length < _limit) {
        _hasMore = false;
      }

      if (reset) {
        _products = newProducts;
      } else {
        _products.addAll(newProducts);
      }

      await _loadTotalProductsByFilter(active);
      notifyListeners();
      return newProducts;
    } catch (e) {
      log('Error loading products: $e');
      return [];
    }
  }

  Future<void> _loadTotalProductsByFilter(bool? active) async {
    try {
      final db = await _dbHelper.db;
      String whereClause = '';
      List<Object?> whereArgs = [];

      if (active != null) {
        whereClause = 'active = ?';
        whereArgs.add(active ? 1 : 0);
      }

      final res = await db.rawQuery(
        whereClause.isNotEmpty
            ? "SELECT COUNT(*) as count FROM products WHERE $whereClause"
            : "SELECT COUNT(*) as count FROM products",
        whereArgs,
      );

      if (res.isNotEmpty) {
        _totalProducts = (res.first['count'] as int?) ?? 0;
      } else {
        _totalProducts = 0;
      }
      notifyListeners();
    } catch (e) {
      log('Error loading total products: $e');
      _totalProducts = 0;
      notifyListeners();
    }
  }

  Future<void> loadProductsByFilter(
    ProductFilter filter, {
    bool reset = true,
  }) async {
    bool? active;
    switch (filter) {
      case ProductFilter.inactive:
        active = false;
        break;
      case ProductFilter.all:
        active = null;
        break;
      case ProductFilter.available:
      case ProductFilter.unavailable:
      case ProductFilter.lowStock:
        active = true;
        break;
    }
    _currentActiveFilter = filter;
    await loadProducts(reset: reset, active: active);
  }

  Future<List<Product>> searchProducts(String query, {bool? active}) async {
    final db = await _dbHelper.db;
    if (query.trim().isEmpty) {
      return _products;
    }

    try {
      String whereClause =
          'LOWER(name) LIKE LOWER(?) OR LOWER(barcode) LIKE LOWER(?)';
      List<Object?> whereArgs = ['%$query%', '%$query%'];

      if (active != null) {
        whereClause += ' AND active = ?';
        whereArgs.add(active ? 1 : 0);
      }

      final result = await db.query(
        'products',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'name ASC',
      );

      return result.map(Product.fromMap).toList();
    } catch (e) {
      log('Error searching products: $e');
      return [];
    }
  }

  Future<void> loadMoreProducts() async {
    if (!_hasMore) return;
    bool? active;
    if (_currentActiveFilter != null) {
      switch (_currentActiveFilter!) {
        case ProductFilter.inactive:
          active = false;
          break;
        default:
          active = true;
      }
    }
    await loadProducts(reset: false, active: active);
  }

  Future<void> toggleProductActive(int productId) async {
    try {
      final db = await _dbHelper.db;
      final result = await db.query(
        'products',
        columns: ['active', 'name'],
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (result.isNotEmpty) {
        final currentActive = (result.first['active'] as int?) == 1;
        final productName = result.first['name'] as String;
        final newActive = !currentActive;

        await db.update(
          'products',
          {'active': newActive ? 1 : 0},
          where: 'id = ?',
          whereArgs: [productId],
        );

        final index = _products.indexWhere((p) => p.id == productId);
        if (index != -1) {
          _products[index].active = newActive;
          notifyListeners();
        }
      }
    } catch (e) {
      log('❌ خطأ في تغيير حالة المنتج: $e');
      rethrow;
    }
  }

  Future<List<Product>> searchProductsByBarcode(String barcode) async {
    final db = await _dbHelper.db;
    try {
      final result = await db.query(
        'products',
        where: 'barcode = ?',
        whereArgs: [barcode],
      );

      return result.map((map) {
        return Product(
          id: map['id'] as int?,
          name: map['name'] as String,
          barcode: map['barcode'] as String?,
          baseUnit: map['base_unit'] as String? ?? 'piece',
          price: (map['price'] as num?)?.toDouble() ?? 0.0,
          quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
          costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0.0,
          addedDate: map['added_date'] as String?,
          hasExpiryDate: (map['has_expiry_date'] as int?) == 1,
          active: (map['active'] as int?) != 0,
        );
      }).toList();
    } catch (e) {
      log('Error searching by barcode: $e');
      return [];
    }
  }

  Future<List<ProductUnit>> searchProductUnitsByBarcode(String barcode) async {
    final db = await _dbHelper.db;
    try {
      final result = await db.query(
        'product_units',
        where: 'barcode = ?',
        whereArgs: [barcode],
      );
      return result.map((map) => ProductUnit.fromMap(map)).toList();
    } catch (e) {
      log('Error searching unit by barcode: $e');
      return [];
    }
  }

  Future<void> addProductUnit(ProductUnit unit) async {
    final db = await _dbHelper.db;
    await db.insert('product_units', unit.toMap());
  }

  Future<List<ProductUnit>> getProductUnits(int productId) async {
    try {
      final db = await _dbHelper.db;
      final result = await db.query(
        'product_units',
        where: 'product_id = ?',
        whereArgs: [productId],
      );
      final units = result.map((map) => ProductUnit.fromMap(map)).toList();
      return _removeDuplicateUnits(units);
    } catch (e) {
      log('Error getting product units: $e');
      return [];
    }
  }

  List<ProductUnit> _removeDuplicateUnits(List<ProductUnit> units) {
    final seen = <int>{};
    return units.where((unit) {
      if (unit.id == null) return false;
      if (seen.contains(unit.id)) return false;
      seen.add(unit.id!);
      return true;
    }).toList();
  }

  Future<void> updateProductUnit(ProductUnit unit) async {
    final db = await _dbHelper.db;
    await db.update(
      'product_units',
      unit.toMap(),
      where: 'id = ?',
      whereArgs: [unit.id],
    );
  }

  Future<void> deleteProductUnit(int unitId) async {
    final db = await _dbHelper.db;
    await db.delete('product_units', where: 'id = ?', whereArgs: [unitId]);
  }

  Future<void> addProduct(Product product) async {
    final db = await _dbHelper.db;
    final safeQuantity = product.quantity.isNaN ? 0.0 : product.quantity;
    final safeCostPrice = product.costPrice.isNaN ? 0.0 : product.costPrice;
    final safePrice = product.price.isNaN ? 0.0 : product.price;
    final hasBarcode = product.barcode != null && product.barcode!.isNotEmpty;

    if (hasBarcode) {
      final existing = await db.query(
        'products',
        where: 'barcode = ?',
        whereArgs: [product.barcode],
      );

      if (existing.isNotEmpty) {
        final oldProduct = existing.first;
        final oldQuantity = (oldProduct['quantity'] as num?)?.toDouble() ?? 0.0;
        final oldCostPrice =
            (oldProduct['cost_price'] as num?)?.toDouble() ?? 0.0;
        final newQuantity = oldQuantity + safeQuantity;

        double newCostPrice;
        if (newQuantity == 0) {
          newCostPrice = 0.0;
        } else {
          newCostPrice =
              ((oldQuantity * oldCostPrice) + (safeQuantity * safeCostPrice)) /
              newQuantity;
        }

        final newCostPriceFixed = double.parse(newCostPrice.toStringAsFixed(2));

        await db.update(
          'products',
          {
            'quantity': newQuantity,
            'cost_price': newCostPriceFixed,
            'price': safePrice,
            'active': product.active ? 1 : 0,
            'has_expiry_date': product.hasExpiryDate ? 1 : 0,
          },
          where: 'id = ?',
          whereArgs: [oldProduct['id']],
        );

        await loadProducts(reset: true);
        notifyListeners();
        return;
      }
    }

    final productMap = {
      'name': product.name,
      'barcode': hasBarcode ? product.barcode : null,
      'base_unit': product.baseUnit,
      'price': safePrice,
      'quantity': safeQuantity,
      'cost_price': safeCostPrice,
      'added_date': product.addedDate,
      'active': product.active ? 1 : 0,
      'has_expiry_date': product.hasExpiryDate ? 1 : 0,
    };

    await db.insert('products', productMap);
    await loadProducts(reset: true);
    notifyListeners();
  }

  Future<void> updateProduct(Product updatedProduct) async {
    if (updatedProduct.id == null) {
      throw Exception('لا يمكن تحديث منتج بدون ID');
    }

    final db = await _dbHelper.db;
    final updateData = <String, dynamic>{
      'name': updatedProduct.name,
      'barcode': updatedProduct.barcode,
      'base_unit': updatedProduct.baseUnit,
      'price': updatedProduct.price,
      'cost_price': updatedProduct.costPrice,
      'quantity': updatedProduct.quantity,
    };

    await db.update(
      'products',
      updateData,
      where: 'id = ?',
      whereArgs: [updatedProduct.id],
    );

    final index = _products.indexWhere((p) => p.id == updatedProduct.id);
    if (index != -1) {
      _products[index] = updatedProduct;
      notifyListeners();
    }

    await loadTotalProducts();
  }

  Future<void> deleteProduct(String idProduct) async {
    final db = await _dbHelper.db;
    await db.delete('products', where: 'id = ?', whereArgs: [idProduct]);
  }

  Future<Product?> getProductById(int id) async {
    try {
      final db = await _dbHelper.db;
      final result = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (result.isEmpty) return null;

      final map = result.first;
      return Product(
        id: map['id'] as int?,
        name: map['name'] as String,
        barcode: map['barcode'] as String?,
        baseUnit: map['base_unit'] as String? ?? 'piece',
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
        costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0.0,
        addedDate: map['added_date'] as String?,
        hasExpiryDate: (map['has_expiry_date'] as int?) == 1,
        active: (map['active'] as int?) != 0,
      );
    } catch (e) {
      log('Error getting product by ID: $e');
      return null;
    }
  }

  Future<List<Product>> searchProductsByName(String name) async {
    try {
      final db = await _dbHelper.db;
      final result = await db.query(
        'products',
        where: 'name LIKE ?',
        whereArgs: ['%$name%'],
      );
      return result.map((map) => Product.fromMap(map)).toList();
    } catch (e) {
      log('Error searching products by name: $e');
      return [];
    }
  }

  Future<List<ProductUnit>> searchProductUnitsByName(String name) async {
    try {
      final db = await _dbHelper.db;
      final result = await db.query(
        'product_units',
        where: 'unit_name LIKE ?',
        whereArgs: ['%$name%'],
      );
      return result.map((map) => ProductUnit.fromMap(map)).toList();
    } catch (e) {
      log('Error searching product units by name: $e');
      return [];
    }
  }

  Future<List<SaleItem>> getSaleItems(int saleId) async {
    try {
      final db = await _dbHelper.db;
      final List<Map<String, dynamic>> maps = await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );
      return maps.map((map) => SaleItem.fromMap(map)).toList();
    } catch (e) {
      log('Error getting sale items: $e');
      return [];
    }
  }

  // ========== دوال الفواتير مع نظام FIFO ==========

  Future<void> addSale({
    required List<CartItem> cartItems,
    required double totalAmount,
    String paymentType = 'cash',
    int? customerId,
    required String userRole,
    required int userId, // ⬅️ جديد: معرف المستخدم
  }) async {
    final db = await _dbHelper.db;

    log('🛒 بدء عملية بيع جديدة - المستخدم: $userId');

    await db.transaction((txn) async {
      // 🔹 تحديد قيمة showForTax
      int showForTax;
      if (userRole == 'tax') {
        showForTax = 1;
        log('🎯 مستخدم ضريبي - الفاتورة مضمنة بالضرائب');
      } else {
        final settings = await txn.query('settings', limit: 1);
        if (settings.isNotEmpty) {
          dynamic taxSetting = settings.first['defaultTaxSetting'];
          if (taxSetting is int) {
            showForTax = taxSetting;
          } else if (taxSetting is String) {
            showForTax = int.tryParse(taxSetting) ?? 0;
          } else {
            showForTax = 0;
          }
        } else {
          showForTax = 0;
        }
      }

      final saleId = await txn.insert('sales', {
        'date': DateTime.now().toIso8601String(),
        'total_amount': totalAmount,
        'total_profit': 0.0,
        'customer_id': customerId,
        'payment_type': paymentType,
        'show_for_tax': showForTax,
        'user_id': userId, // ⬅️ جديد: حفظ معرف المستخدم
      });

      double totalProfit = 0.0;
      List<Map<String, dynamic>> allBatchDeductions = [];

      // 🔹 معالجة كل عنصر في السلة
      for (var item in cartItems) {
        if (item.isService) {
          // معالجة الخدمة
          final double actualPrice = item.unitPrice;
          final double subtotal = item.totalPrice;

          await txn.insert('sale_items', {
            'sale_id': saleId,
            'item_type': 'service',
            'product_id': null,
            'unit_id': null,
            'quantity': item.quantity,
            'unit_type': 'service',
            'custom_unit_name': item.serviceName,
            'price': actualPrice,
            'cost_price': 0.0,
            'subtotal': subtotal,
            'profit': 0.0,
          });
          continue;
        }

        // معالجة المنتج
        final product = item.product!;
        double requiredQtyInBaseUnit = item.quantity;

        if (item.selectedUnit != null) {
          requiredQtyInBaseUnit = item.quantity * item.selectedUnit!.containQty;
        }

        // 🔹 خصم من الدفعات الأقدم أولاً (FIFO) - إذا كانت موجودة فقط
        final batches = await txn.rawQuery(
          '''
        SELECT * FROM product_batches 
        WHERE product_id = ? 
          AND remaining_quantity > 0 
          AND active = 1
        ORDER BY 
          CASE 
            WHEN expiry_date IS NOT NULL AND expiry_date != '' 
            THEN expiry_date 
            ELSE '9999-12-31' 
          END ASC,
          created_at ASC
      ''',
          [product.id],
        );

        List<Map<String, dynamic>> itemDeductions = [];
        double itemTotalCost = 0.0;
        double itemProfit = 0.0;

        // إذا في دفعات، نخصم منها
        if (batches.isNotEmpty) {
          double remainingToDeduct = requiredQtyInBaseUnit;

          for (var batch in batches) {
            if (remainingToDeduct <= 0) break;

            final batchId = batch['id'] as int;
            final double batchQty =
                (batch['remaining_quantity'] as num).toDouble();
            final double batchCost = (batch['cost_price'] as num).toDouble();
            final String? batchExpiry = batch['expiry_date'] as String?;

            final double toDeduct =
                batchQty >= remainingToDeduct ? remainingToDeduct : batchQty;

            // تحديث الدفعة
            final double newQty = batchQty - toDeduct;
            await txn.update(
              'product_batches',
              {'remaining_quantity': newQty, 'active': newQty > 0 ? 1 : 0},
              where: 'id = ?',
              whereArgs: [batchId],
            );

            itemDeductions.add({
              'batchId': batchId,
              'quantity': toDeduct,
              'costPrice': batchCost,
              'expiryDate': batchExpiry,
            });

            // حساب التكلفة والربح
            final double batchCostAmount = toDeduct * batchCost;
            itemTotalCost += batchCostAmount;

            final double unitPrice =
                item.selectedUnit?.sellPrice ?? product.price;
            double soldQtyInUnit;

            if (item.selectedUnit != null) {
              soldQtyInUnit = toDeduct / item.selectedUnit!.containQty;
            } else {
              soldQtyInUnit = toDeduct;
            }

            final double batchRevenue = unitPrice * soldQtyInUnit;
            final double batchProfit =
                batchRevenue - (batchCost * soldQtyInUnit);
            itemProfit += batchProfit;

            remainingToDeduct -= toDeduct;
          }

          log('📦 تم خصم من الدفعات للمنتج ${product.name}');
        } else {
          // إذا ما في دفعات، نحسب التكلفة من السعر الأساسي للمنتج
          itemTotalCost = requiredQtyInBaseUnit * product.costPrice;

          final double unitPrice =
              item.selectedUnit?.sellPrice ?? product.price;
          double soldQtyInUnit =
              item.selectedUnit != null
                  ? requiredQtyInBaseUnit / item.selectedUnit!.containQty
                  : requiredQtyInBaseUnit;

          final double revenue = unitPrice * soldQtyInUnit;
          itemProfit = revenue - itemTotalCost;

          log(
            '⚠️ لا توجد دفعات للمنتج ${product.name} - تم البيع بدون خصم من الدفعات',
          );
        }

        // حفظ تفاصيل الخصم
        allBatchDeductions.addAll(
          itemDeductions.map(
            (d) => {
              ...d,
              'productId': product.id,
              'productName': product.name,
              'saleId': saleId,
            },
          ),
        );

        // 🔹 إضافة عنصر الفاتورة
        final double actualPrice =
            item.selectedUnit?.sellPrice ?? product.price;
        final double subtotal = actualPrice * item.quantity;
        final double avgCost =
            requiredQtyInBaseUnit > 0
                ? itemTotalCost / requiredQtyInBaseUnit
                : 0;

        await txn.insert('sale_items', {
          'sale_id': saleId,
          'item_type': 'product',
          'product_id': product.id,
          'unit_id': item.selectedUnit?.id,
          'quantity': item.quantity,
          'unit_type': item.selectedUnit != null ? 'custom' : product.baseUnit,
          'custom_unit_name': item.selectedUnit?.unitName,
          'price': actualPrice,
          'cost_price': avgCost,
          'subtotal': subtotal,
          'profit': itemProfit,
          'batch_details': jsonEncode(itemDeductions),
        });

        totalProfit += itemProfit;

        // 🔹 تحديث كمية المنتج الإجمالية
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity - ? WHERE id = ?',
          [requiredQtyInBaseUnit, product.id],
        );

        log(
          '📦 تم معالجة المنتج ${product.name} - الكمية: $requiredQtyInBaseUnit',
        );
      }

      // 🔹 تحديث الربح الإجمالي في الفاتورة
      await txn.update(
        'sales',
        {'total_profit': totalProfit},
        where: 'id = ?',
        whereArgs: [saleId],
      );

      // 🔹 حفظ سجل الدفعات (اختياري)
      try {
        await txn.execute('''
        CREATE TABLE IF NOT EXISTS sale_batch_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sale_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          batch_id INTEGER NOT NULL,
          deducted_quantity REAL NOT NULL,
          cost_price REAL NOT NULL,
          expiry_date TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

        for (var deduction in allBatchDeductions) {
          await txn.insert('sale_batch_log', {
            'sale_id': saleId,
            'product_id': deduction['productId'],
            'batch_id': deduction['batchId'],
            'deducted_quantity': deduction['quantity'],
            'cost_price': deduction['costPrice'],
            'expiry_date': deduction['expiryDate'],
          });
        }
      } catch (e) {
        log('⚠️ ملاحظة: لم يتم حفظ سجل الدفعات - $e');
      }

      // 🔹 تحديث رصيد الزبون إذا كانت فاتورة آجلة
      if (paymentType == 'credit' && customerId != null) {
        await txn.rawUpdate(
          '''
        INSERT OR REPLACE INTO customer_balance 
        (customer_id, balance, last_updated)
        VALUES (
          ?,
          COALESCE((SELECT balance FROM customer_balance WHERE customer_id = ?), 0) + ?,
          ?
        )
        ''',
          [
            customerId,
            customerId,
            totalAmount,
            DateTime.now().toIso8601String(),
          ],
        );
      }

      log(
        '✅ تم إتمام الفاتورة رقم: $saleId - الربح: $totalProfit - المستخدم: $userId',
      );
    });

    notifyListeners();
  }

  Future<void> updateSale({
    required Sale originalSale,
    required List<CartItem> cartItems,
    required double totalAmount,
    required String userRole,
  }) async {
    final db = await _dbHelper.db;

    log('🔄 بدء تحديث الفاتورة ID: ${originalSale.id}');

    await db.transaction((txn) async {
      // 🔹 1️⃣ جلب الفاتورة الأصلية
      final saleResult = await txn.query(
        'sales',
        columns: ['id', 'total_amount', 'customer_id', 'payment_type'],
        where: 'id = ?',
        whereArgs: [originalSale.id],
        limit: 1,
      );

      if (saleResult.isEmpty) {
        throw Exception('الفاتورة الأصلية غير موجودة');
      }

      final oldSale = saleResult.first;
      final double oldTotalAmount = (oldSale['total_amount'] as num).toDouble();
      final int? oldCustomerId = oldSale['customer_id'] as int?;
      final String oldPaymentType = oldSale['payment_type'] as String;

      // 🔹 2️⃣ تحديد showForTax الجديدة
      int newShowForTax;
      if (userRole == 'tax') {
        newShowForTax = 1;
      } else {
        final settings = await txn.query('settings', limit: 1);
        if (settings.isNotEmpty) {
          dynamic taxSetting = settings.first['defaultTaxSetting'];
          if (taxSetting is int) {
            newShowForTax = taxSetting;
          } else if (taxSetting is String) {
            newShowForTax = int.tryParse(taxSetting) ?? 0;
          } else {
            newShowForTax = 0;
          }
        } else {
          newShowForTax = 0;
        }
      }

      // 🔹 3️⃣ التحقق من توفر الكميات الجديدة
      for (var item in cartItems) {
        if (item.isService) continue;

        final product = item.product!;
        double requiredQty = item.quantity;

        if (item.selectedUnit != null) {
          requiredQty = item.quantity * item.selectedUnit!.containQty;
        }

        if (requiredQty <= 0) continue;

        final batchResult = await txn.rawQuery(
          '''
          SELECT SUM(remaining_quantity) as total_available
          FROM product_batches 
          WHERE product_id = ? AND remaining_quantity > 0 AND active = 1
        ''',
          [product.id],
        );

        final double totalAvailable =
            (batchResult.first['total_available'] as num?)?.toDouble() ?? 0;

        if (requiredQty > totalAvailable) {
          throw Exception(
            'المنتج "${product.name}" لا يوجد به كمية كافية. '
            'المتاح: ${totalAvailable.toStringAsFixed(2)}، '
            'المطلوب: ${requiredQty.toStringAsFixed(2)}',
          );
        }
      }

      // 🔹 4️⃣ جلب عناصر الفاتورة القديمة
      final oldItems = await txn.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [originalSale.id],
      );

      // 🔹 5️⃣ إرجاع الكميات القديمة من الدفعات أولاً
      for (var oldItem in oldItems) {
        final int? productId = oldItem['product_id'] as int?;
        if (productId == null) continue;

        final double oldQuantity = (oldItem['quantity'] as num).toDouble();
        final int? oldUnitId = oldItem['unit_id'] as int?;

        double oldQtyInBaseUnit = oldQuantity;

        if (oldUnitId != null) {
          final unitResult = await txn.query(
            'product_units',
            columns: ['contain_qty'],
            where: 'id = ?',
            whereArgs: [oldUnitId],
          );

          if (unitResult.isNotEmpty) {
            final double containQty =
                (unitResult.first['contain_qty'] as num).toDouble();
            oldQtyInBaseUnit = oldQuantity * containQty;
          }
        }

        // محاولة إرجاع الكمية للدفعات القديمة
        if (oldItem['batch_details'] != null &&
            oldItem['batch_details'].toString().isNotEmpty) {
          try {
            final oldBatchDetails = jsonDecode(
              oldItem['batch_details'] as String,
            );
            final List<Map<String, dynamic>> oldDeductions =
                List<Map<String, dynamic>>.from(oldBatchDetails);

            for (var deduction in oldDeductions) {
              final batchId = deduction['batchId'] as int;
              final double quantity = (deduction['quantity'] as num).toDouble();

              final batch = await txn.query(
                'product_batches',
                where: 'id = ?',
                whereArgs: [batchId],
              );

              if (batch.isNotEmpty) {
                final double currentQty =
                    (batch.first['remaining_quantity'] as num).toDouble();
                await txn.update(
                  'product_batches',
                  {'remaining_quantity': currentQty + quantity, 'active': 1},
                  where: 'id = ?',
                  whereArgs: [batchId],
                );
              }
            }
          } catch (e) {
            log('⚠️ خطأ في إرجاع تفاصيل الدفعات القديمة: $e');
          }
        }

        // إرجاع الكمية للمنتج الإجمالي
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity + ? WHERE id = ?',
          [oldQtyInBaseUnit, productId],
        );
      }

      // 🔹 6️⃣ حذف العناصر القديمة
      await txn.delete(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [originalSale.id],
      );

      // 🔹 7️⃣ حذف سجل الدفعات القديم
      try {
        await txn.delete(
          'sale_batch_log',
          where: 'sale_id = ?',
          whereArgs: [originalSale.id],
        );
      } catch (e) {
        // تجاهل الخطأ إذا الجدول غير موجود
      }

      // 🔹 8️⃣ إضافة العناصر الجديدة مع خصم من الدفعات
      double totalProfit = 0.0;
      List<Map<String, dynamic>> allBatchDeductions = [];

      for (var item in cartItems) {
        if (item.quantity == 0) continue;

        if (item.isService) {
          final double actualPrice = item.unitPrice;
          final double subtotal = item.totalPrice;

          await txn.insert('sale_items', {
            'sale_id': originalSale.id,
            'item_type': 'service',
            'product_id': null,
            'unit_id': null,
            'quantity': item.quantity,
            'unit_type': 'service',
            'custom_unit_name': item.serviceName,
            'price': actualPrice,
            'cost_price': 0.0,
            'subtotal': subtotal,
            'profit': 0.0,
          });
          continue;
        }

        final product = item.product!;
        double requiredQtyInBaseUnit = item.quantity;

        if (item.selectedUnit != null) {
          requiredQtyInBaseUnit = item.quantity * item.selectedUnit!.containQty;
        }

        // خصم من الدفعات الأقدم أولاً
        final batches = await txn.rawQuery(
          '''
          SELECT * FROM product_batches 
          WHERE product_id = ? 
            AND remaining_quantity > 0 
            AND active = 1
          ORDER BY 
            CASE 
              WHEN expiry_date IS NOT NULL AND expiry_date != '' 
              THEN expiry_date 
              ELSE '9999-12-31' 
            END ASC,
            created_at ASC
        ''',
          [product.id],
        );

        if (batches.isEmpty && requiredQtyInBaseUnit > 0) {
          throw Exception('لا توجد دفعات متاحة للمنتج ${product.name}');
        }

        double remainingToDeduct = requiredQtyInBaseUnit;
        List<Map<String, dynamic>> itemDeductions = [];
        double itemTotalCost = 0.0;
        double itemProfit = 0.0;

        for (var batch in batches) {
          if (remainingToDeduct <= 0) break;

          final batchId = batch['id'] as int;
          final double batchQty =
              (batch['remaining_quantity'] as num).toDouble();
          final double batchCost = (batch['cost_price'] as num).toDouble();
          final String? batchExpiry = batch['expiry_date'] as String?;

          final double toDeduct =
              batchQty >= remainingToDeduct ? remainingToDeduct : batchQty;

          // تحديث الدفعة
          final double newQty = batchQty - toDeduct;
          await txn.update(
            'product_batches',
            {'remaining_quantity': newQty, 'active': newQty > 0 ? 1 : 0},
            where: 'id = ?',
            whereArgs: [batchId],
          );

          itemDeductions.add({
            'batchId': batchId,
            'quantity': toDeduct,
            'costPrice': batchCost,
            'expiryDate': batchExpiry,
          });

          final double batchCostAmount = toDeduct * batchCost;
          itemTotalCost += batchCostAmount;

          final double unitPrice =
              item.selectedUnit?.sellPrice ?? product.price;
          double soldQtyInUnit;

          if (item.selectedUnit != null) {
            soldQtyInUnit = toDeduct / item.selectedUnit!.containQty;
          } else {
            soldQtyInUnit = toDeduct;
          }

          final double batchRevenue = unitPrice * soldQtyInUnit;
          final double batchProfit = batchRevenue - (batchCost * soldQtyInUnit);
          itemProfit += batchProfit;

          remainingToDeduct -= toDeduct;
        }

        if (remainingToDeduct > 0) {
          throw Exception('كمية غير كافية للمنتج ${product.name}');
        }

        allBatchDeductions.addAll(
          itemDeductions.map(
            (d) => {
              ...d,
              'productId': product.id,
              'productName': product.name,
              'saleId': originalSale.id,
            },
          ),
        );

        final double actualPrice =
            item.selectedUnit?.sellPrice ?? product.price;
        final double subtotal = actualPrice * item.quantity;
        final double avgCost =
            requiredQtyInBaseUnit > 0
                ? itemTotalCost / requiredQtyInBaseUnit
                : 0;

        await txn.insert('sale_items', {
          'sale_id': originalSale.id,
          'item_type': 'product',
          'product_id': product.id,
          'unit_id': item.selectedUnit?.id,
          'quantity': item.quantity,
          'unit_type': item.selectedUnit != null ? 'custom' : product.baseUnit,
          'custom_unit_name': item.selectedUnit?.unitName,
          'price': actualPrice,
          'cost_price': avgCost,
          'subtotal': subtotal,
          'profit': itemProfit,
          'batch_details': jsonEncode(itemDeductions),
        });

        totalProfit += itemProfit;

        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity - ? WHERE id = ?',
          [requiredQtyInBaseUnit, product.id],
        );
      }

      // 🔹 9️⃣ تحديث بيانات الفاتورة الرئيسية
      await txn.update(
        'sales',
        {
          'total_amount': totalAmount,
          'total_profit': totalProfit,
          'show_for_tax': newShowForTax,
          'date': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [originalSale.id],
      );

      // 🔹 🔟 حفظ سجل الدفعات الجديد
      try {
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS sale_batch_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sale_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            batch_id INTEGER NOT NULL,
            deducted_quantity REAL NOT NULL,
            cost_price REAL NOT NULL,
            expiry_date TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        for (var deduction in allBatchDeductions) {
          await txn.insert('sale_batch_log', {
            'sale_id': originalSale.id,
            'product_id': deduction['productId'],
            'batch_id': deduction['batchId'],
            'deducted_quantity': deduction['quantity'],
            'cost_price': deduction['costPrice'],
            'expiry_date': deduction['expiryDate'],
          });
        }
      } catch (e) {
        log('⚠️ ملاحظة: لم يتم حفظ سجل الدفعات - $e');
      }

      // 🔹 1️⃣1️⃣ تحديث رصيد الزبون إذا تغير المبلغ
      final double difference = totalAmount - oldTotalAmount;

      if (oldPaymentType == 'credit' &&
          oldCustomerId != null &&
          difference != 0) {
        await txn.rawUpdate(
          '''
          UPDATE customer_balance 
          SET balance = balance + ?, last_updated = ?
          WHERE customer_id = ?
          ''',
          [difference, DateTime.now().toIso8601String(), oldCustomerId],
        );
      }

      log('✅ تم تحديث الفاتورة رقم: ${originalSale.id} - الفرق: $difference');
    });

    // تحديث القوائم المحلية
    _refreshSalesInLists(originalSale.id, totalAmount);
    notifyListeners();
  }

  Future<void> deleteSale(int saleId) async {
    final db = await _dbHelper.db;

    await db.transaction((txn) async {
      // 1️⃣ جلب الفاتورة
      final sale = await txn.query(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
        limit: 1,
      );

      if (sale.isEmpty) {
        throw Exception('الفاتورة غير موجودة');
      }

      final saleData = sale.first;
      final double totalAmount = (saleData['total_amount'] as num).toDouble();
      final String paymentType = saleData['payment_type'] as String;
      final int? customerId = saleData['customer_id'] as int?;

      // 2️⃣ جلب تفاصيل خصم الدفعات
      List<Map<String, dynamic>> batchReturns = [];

      try {
        final batchLog = await txn.query(
          'sale_batch_log',
          where: 'sale_id = ?',
          whereArgs: [saleId],
        );

        if (batchLog.isNotEmpty) {
          for (var log in batchLog) {
            batchReturns.add({
              'batchId': log['batch_id'] as int,
              'quantity': log['deducted_quantity'] as double,
              'costPrice': log['cost_price'] as double,
              'productId': log['product_id'] as int,
              'expiryDate': log['expiry_date'] as String?,
            });
          }
        } else {
          final items = await txn.query(
            'sale_items',
            where: 'sale_id = ? AND product_id IS NOT NULL',
            whereArgs: [saleId],
          );

          for (var item in items) {
            if (item['batch_details'] != null) {
              final details = jsonDecode(item['batch_details'] as String);
              final List<Map<String, dynamic>> itemDeductions =
                  List<Map<String, dynamic>>.from(details);

              for (var deduction in itemDeductions) {
                batchReturns.add({
                  ...deduction,
                  'productId': item['product_id'] as int,
                });
              }
            }
          }
        }
      } catch (e) {
        log('⚠️ لم يتم العثور على سجل الدفعات: $e');
      }

      // 3️⃣ إرجاع الكميات للدفعات
      for (var returnItem in batchReturns) {
        final batchId = returnItem['batchId'] as int;
        final double quantity = (returnItem['quantity'] as num).toDouble();
        final int productId = returnItem['productId'] as int;

        final batch = await txn.query(
          'product_batches',
          where: 'id = ?',
          whereArgs: [batchId],
        );

        if (batch.isNotEmpty) {
          final double currentQty =
              (batch.first['remaining_quantity'] as num).toDouble();
          await txn.update(
            'product_batches',
            {'remaining_quantity': currentQty + quantity, 'active': 1},
            where: 'id = ?',
            whereArgs: [batchId],
          );
        } else {
          await txn.insert('product_batches', {
            'product_id': productId,
            'quantity': quantity,
            'remaining_quantity': quantity,
            'cost_price': returnItem['costPrice'] ?? 0,
            'expiry_date':
                returnItem['expiryDate'] ??
                DateTime.now().add(Duration(days: 365)).toIso8601String(),
            'production_date': DateTime.now().toIso8601String(),
            'active': 1,
            'created_at': DateTime.now().toIso8601String(),
          });
        }

        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity + ? WHERE id = ?',
          [quantity, productId],
        );
      }

      // 4️⃣ إذا لم تكن هناك تفاصيل دفعات، نرجع الكميات العادية
      if (batchReturns.isEmpty) {
        final saleItems = await txn.query(
          'sale_items',
          where: 'sale_id = ?',
          whereArgs: [saleId],
        );

        for (var item in saleItems) {
          final int? productId = item['product_id'] as int?;
          if (productId == null) continue;

          final double quantity = (item['quantity'] as num).toDouble();
          final int? unitId = item['unit_id'] as int?;

          double qtyToReturn = quantity;

          if (unitId != null) {
            final unit = await txn.query(
              'product_units',
              where: 'id = ?',
              whereArgs: [unitId],
            );

            if (unit.isNotEmpty) {
              final double containQty =
                  (unit.first['contain_qty'] as num).toDouble();
              qtyToReturn = quantity * containQty;
            }
          }

          await txn.rawUpdate(
            'UPDATE products SET quantity = quantity + ? WHERE id = ?',
            [qtyToReturn, productId],
          );
        }
      }

      // 5️⃣ تعديل رصيد الزبون إذا كانت فاتورة آجلة
      if (paymentType == 'credit' && customerId != null) {
        await txn.rawUpdate(
          '''
          UPDATE customer_balance 
          SET balance = balance - ?, last_updated = ?
          WHERE customer_id = ?
          ''',
          [totalAmount, DateTime.now().toIso8601String(), customerId],
        );
      }

      // 6️⃣ حذف السجلات
      await txn.delete(
        'sale_batch_log',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );
      await txn.delete('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
      await txn.delete('sales', where: 'id = ?', whereArgs: [saleId]);

      log('🗑️ تم حذف الفاتورة $saleId');
    });

    // تحديث القوائم المحلية
    _allSales.removeWhere((sale) => sale.id == saleId);
    _displayedSales.removeWhere((sale) => sale.id == saleId);
    notifyListeners();
  }

  // ========== دوال مساعدة ==========

  Future<int> _determineShowForTax(String userRole, Database db) async {
    if (userRole == 'tax') {
      return 1;
    } else {
      final settings = await db.query('settings', limit: 1);
      if (settings.isNotEmpty) {
        dynamic taxSetting = settings.first['defaultTaxSetting'];
        if (taxSetting is int) {
          return taxSetting;
        } else if (taxSetting is String) {
          return int.tryParse(taxSetting) ?? 0;
        }
      }
      return 0;
    }
  }

  Future<void> _validateStockQuantities(
    List<CartItem> cartItems,
    DatabaseExecutor db,
  ) async {
    for (var item in cartItems) {
      final product = item.product;
      final List<Map<String, dynamic>> result = await db.query(
        'products',
        columns: ['quantity', 'name'],
        where: 'id = ?',
        whereArgs: [product?.id],
      );

      if (result.isNotEmpty) {
        final dynamic quantityValue = result.first['quantity'];
        final double currentQuantity =
            (quantityValue is int)
                ? quantityValue.toDouble()
                : quantityValue as double;

        final String productName = result.first['name'] as String;

        double requiredQuantity = item.quantity;
        if (item.selectedUnit != null) {
          requiredQuantity = item.quantity * item.selectedUnit!.containQty;
        }

        if (requiredQuantity > 0 && currentQuantity < requiredQuantity) {
          throw Exception(
            'المنتج "$productName" لا يوجد به كمية كافية. '
            'الكمية المتاحة: ${currentQuantity.toStringAsFixed(2)} ${translateUnit(product!.baseUnit)}',
          );
        }
      } else {
        throw Exception('المنتج غير موجود في قاعدة البيانات');
      }
    }
  }

  void _refreshSalesInLists(int saleId, double newTotalAmount) {
    final allIndex = _allSales.indexWhere((s) => s.id == saleId);
    if (allIndex != -1) {
      _allSales[allIndex] = Sale(
        id: saleId,
        date: DateTime.now().toIso8601String(),
        totalAmount: newTotalAmount,
        totalProfit: _allSales[allIndex].totalProfit,
        customerId: _allSales[allIndex].customerId,
        paymentType: _allSales[allIndex].paymentType,
        showForTax: _allSales[allIndex].showForTax,
      );
    }

    final displayedIndex = _displayedSales.indexWhere((s) => s.id == saleId);
    if (displayedIndex != -1) {
      _displayedSales[displayedIndex] = Sale(
        id: saleId,
        date: DateTime.now().toIso8601String(),
        totalAmount: newTotalAmount,
        totalProfit: _displayedSales[displayedIndex].totalProfit,
        customerId: _displayedSales[displayedIndex].customerId,
        paymentType: _displayedSales[displayedIndex].paymentType,
        showForTax: _displayedSales[displayedIndex].showForTax,
      );
    }
  }

  // دالة لتحميل الفواتير حسب التاريخ
  Future<void> loadSalesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final db = await _dbHelper.db;

      final results = await db.rawQuery(
        '''
        SELECT 
          s.*,
          c.name as customer_name,
          COALESCE(cb.balance, 0) as customer_balance
        FROM sales s
        LEFT JOIN customers c ON s.customer_id = c.id
        LEFT JOIN customer_balance cb ON s.customer_id = cb.customer_id
        WHERE DATE(s.date) BETWEEN DATE(?) AND DATE(?)
        ORDER BY s.date DESC
      ''',
        [
          startDate.toIso8601String().split('T').first,
          endDate.toIso8601String().split('T').first,
        ],
      );

      _displayedSales = results.map((map) => Sale.fromMap(map)).toList();
      _currentStartDate = startDate;
      _currentEndDate = endDate;
      notifyListeners();

      log('📊 تم تحميل ${_displayedSales.length} فاتورة للفترة المحددة');
    } catch (e) {
      log('❌ خطأ في تحميل الفواتير: $e');
    }
  }

  // دالة لتحميل جميع الفواتير
  Future<void> loadAllSales() async {
    try {
      final db = await _dbHelper.db;

      final results = await db.rawQuery('''
        SELECT 
          s.*,
          c.name as customer_name,
          COALESCE(cb.balance, 0) as customer_balance
        FROM sales s
        LEFT JOIN customers c ON s.customer_id = c.id
        LEFT JOIN customer_balance cb ON s.customer_id = cb.customer_id
        ORDER BY s.date DESC
        LIMIT 100
      ''');

      _allSales = results.map((map) => Sale.fromMap(map)).toList();
      _displayedSales = List.from(_allSales);
      notifyListeners();

      log('📊 تم تحميل ${_allSales.length} فاتورة');
    } catch (e) {
      log('❌ خطأ في تحميل الفواتير: $e');
    }
  }
}
