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

  // ✅ إعادة تعيين حالة الـ pagination
  void resetPagination() {
    _page = 0;
    _hasMore = true;
    _products.clear();
    notifyListeners();
  }

  // ✅ تحميل عدد المنتجات الإجمالي
  Future<void> loadTotalProducts() async {
    final db = await _dbHelper.db;
    final res = await db.rawQuery("SELECT COUNT(*) as count FROM products");
    _totalProducts = res.first['count'] as int;
    notifyListeners();
  }

  int lowStockCount = 0;
  int outOfStockCount = 0;

  Future<void> loadStockCounts(int threshold) async {
    lowStockCount = await loadLowStockProductsCount(threshold);
    outOfStockCount = await loadOutOfStockProductsCount();
    notifyListeners();
  }

  //تحميل عدد المنتجات المنخفضة
  Future<int> loadLowStockProductsCount(int lowStockThreshold) async {
    final db = await _dbHelper.db;

    final res = await db.rawQuery(
      "SELECT COUNT(*) as count FROM products WHERE quantity <= ? AND quantity > 0",
      [lowStockThreshold],
    );

    return Sqflite.firstIntValue(res) ?? 0;
  }

  //تحميل عدد المنتجات الغير متوفرة
  Future<int> loadOutOfStockProductsCount() async {
    final db = await _dbHelper.db;

    final res = await db.rawQuery(
      "SELECT COUNT(*) as count FROM products WHERE quantity <= 0",
    );

    return Sqflite.firstIntValue(res) ?? 0;
  }

  // ✅ التحميل التدريجي للمنتجات مع تحسين الأداء
  // في ProductProvider.dart - تحديث دالة loadProducts

  Future<List<Product>> loadProducts({bool reset = false, bool? active}) async {
    if (!reset && !_hasMore) return [];

    if (reset) {
      resetPagination();
    }

    final db = await _dbHelper.db;

    try {
      String whereClause = '';
      List<Object?> whereArgs = [];

      // بناء الـ WHERE clause بناءً على حالة active
      if (active != null) {
        whereClause = 'active = ?';
        whereArgs.add(active ? 1 : 0);
      }

      print(
        'Loading products with filter: active=$active, where: $whereClause',
      );

      final result = await db.query(
        'products',
        where: whereClause.isNotEmpty ? whereClause : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        limit: _limit,
        offset: _page * _limit,
        orderBy: 'id DESC',
      );

      print('Found ${result.length} products');

      if (result.isEmpty) {
        _hasMore = false;
        return [];
      }

      // تحويل النتائج إلى كائنات Product
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
                hasExpiry: (map['has_expiry'] as int?) == 1,
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

      // تحديث الحالة
      _page++;

      if (newProducts.length < _limit) {
        _hasMore = false;
      }

      // إضافة المنتجات الجديدة للقائمة
      if (reset) {
        _products = newProducts;
      } else {
        _products.addAll(newProducts);
      }

      // تحميل العدد الإجمالي
      await _loadTotalProductsByFilter(active);

      notifyListeners();
      return newProducts;
    } catch (e) {
      log('Error loading products: $e');
      return [];
    }
  }

  // دالة جديدة: تحميل العدد الإجمالي بناءً على الفلتر
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

  // تحديث دالة loadProductsByFilter
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
        active = null; // جميع المنتجات
        break;
      case ProductFilter.available:
      case ProductFilter.unavailable:
      case ProductFilter.lowStock:
        active = true; // المنتجات النشطة فقط
        break;
    }

    _currentActiveFilter = filter;
    await loadProducts(reset: reset, active: active);
  }

  // البحث عن المنتجات (لا يستخدم التحميل التدريجي)
  Future<List<Product>> searchProducts(String query, {bool? active}) async {
    final db = await _dbHelper.db;
    if (query.trim().isEmpty) {
      return _products;
    }

    try {
      String whereClause =
          'LOWER(name) LIKE LOWER(?) OR LOWER(barcode) LIKE LOWER(?)';
      List<Object?> whereArgs = ['%$query%', '%$query%'];

      // إضافة شرط active إذا تم تمريره
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

  // في ProductProvider.dart أضف هذه الدالة:

  Future<void> toggleProductActive(int productId) async {
    try {
      final db = await _dbHelper.db;

      // الحصول على الحالة الحالية
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

        // تحديث الحالة
        await db.update(
          'products',
          {'active': newActive ? 1 : 0},
          where: 'id = ?',
          whereArgs: [productId],
        );

        log(
          '✅ تم ${newActive ? 'تفعيل' : 'تعطيل'} المنتج: $productName (ID: $productId)',
        );

        // تحديث القائمة المحلية
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

  // ✅ البحث عن منتج بواسطة الباركود (بحث دقيق)
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
          hasExpiry: map['has_expiry'] == 1,
          hasExpiryDate: (map['has_expiry_date'] as int?) == 1,
          active: (map['active'] as int?) != 0,
        );
      }).toList();
    } catch (e) {
      log('Error searching by barcode: $e');
      return [];
    }
  }

  // أضف هذه الدالة في ProductProvider
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

  // إضافة وحدة جديدة للمنتج
  Future<void> addProductUnit(ProductUnit unit) async {
    final db = await _dbHelper.db;
    await db.insert('product_units', unit.toMap());
  }

  // جلب جميع وحدات منتج معين
  // في ProductProvider.dart
  Future<List<ProductUnit>> getProductUnits(int productId) async {
    try {
      final db = await _dbHelper.db;
      final result = await db.query(
        'product_units',
        where: 'product_id = ?',
        whereArgs: [productId],
      );

      // تحويل النتائج وإزالة التكرار
      final units = result.map((map) => ProductUnit.fromMap(map)).toList();
      return _removeDuplicateUnits(units);
    } catch (e) {
      log('Error getting product units: $e');
      return [];
    }
  }

  // دالة مساعدة لإزالة التكرار
  List<ProductUnit> _removeDuplicateUnits(List<ProductUnit> units) {
    final seen = <int>{};
    return units.where((unit) {
      if (unit.id == null) return false;
      if (seen.contains(unit.id)) return false;
      seen.add(unit.id!);
      return true;
    }).toList();
  }

  // تحديث وحدة منتج
  Future<void> updateProductUnit(ProductUnit unit) async {
    final db = await _dbHelper.db;
    await db.update(
      'product_units',
      unit.toMap(),
      where: 'id = ?',
      whereArgs: [unit.id],
    );
  }

  // حذف وحدة منتج
  Future<void> deleteProductUnit(int unitId) async {
    final db = await _dbHelper.db;
    await db.delete('product_units', where: 'id = ?', whereArgs: [unitId]);
  }

  // البحث عن وحدة بالباركود

  Future<void> addProduct(Product product) async {
    final db = await _dbHelper.db;

    // حماية القيم من NaN
    final safeQuantity = product.quantity.isNaN ? 0.0 : product.quantity;
    final safeCostPrice = product.costPrice.isNaN ? 0.0 : product.costPrice;
    final safePrice = product.price.isNaN ? 0.0 : product.price;

    // نحدد إذا المنتج عنده باركود
    final hasBarcode = product.barcode != null && product.barcode!.isNotEmpty;

    if (hasBarcode) {
      // تحقق إذا المنتج موجود مسبقًا حسب الباركود
      final existing = await db.query(
        'products',
        where: 'barcode = ?',
        whereArgs: [product.barcode],
      );

      if (existing.isNotEmpty) {
        // المنتج موجود مسبقًا → تحديثه
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
            // ⬅️ تحديث حقول active و has_expiry_date
            'active': product.active ? 1 : 0,
            'has_expiry_date': product.hasExpiryDate ? 1 : 0,
          },
          where: 'id = ?',
          whereArgs: [oldProduct['id']],
        );

        // إعادة تحميل البيانات
        await loadProducts(reset: true);
        notifyListeners();
        return; // خلصنا التحديث
      }
    }

    // إضافة منتج جديد سواء عنده باركود أو لا
    final productMap = {
      'name': product.name,
      'barcode': hasBarcode ? product.barcode : null,
      'base_unit': product.baseUnit,
      'price': safePrice,
      'quantity': safeQuantity,
      'cost_price': safeCostPrice,
      'added_date': product.addedDate,
      // ⬅️ إضافة حقول active و has_expiry_date
      'active': product.active ? 1 : 0,
      'has_expiry_date': product.hasExpiryDate ? 1 : 0,
    };

    print('إضافة منتج جديد: $productMap'); // للتصحيح

    await db.insert('products', productMap);

    // إعادة تحميل البيانات
    await loadProducts(reset: true);
    notifyListeners();
  }

  Future<void> updateProduct(Product updatedProduct) async {
    if (updatedProduct.id == null) {
      throw Exception('لا يمكن تحديث منتج بدون ID');
    }

    final db = await _dbHelper.db;

    // تحديث جميع الحقول بشكل كامل
    final updateData = <String, dynamic>{
      'name': updatedProduct.name,
      'barcode': updatedProduct.barcode,
      'base_unit': updatedProduct.baseUnit,
      'price': updatedProduct.price,
      'cost_price': updatedProduct.costPrice,
      'quantity': updatedProduct.quantity,
    };

    // استخدام ID للتحديث
    await db.update(
      'products',
      updateData,
      where: 'id = ?',
      whereArgs: [updatedProduct.id],
    );

    // تحديث القائمة المحلية
    final index = _products.indexWhere((p) => p.id == updatedProduct.id);
    if (index != -1) {
      _products[index] = updatedProduct;
      notifyListeners();
    }

    // تحديث العدد الإجمالي
    await loadTotalProducts();
  }

  Future<void> deleteProduct(String idProduct) async {
    final db = await _dbHelper.db;
    await db.delete('products', where: 'id = ?', whereArgs: [idProduct]);
  }

  Future<void> addSale({
    required List<CartItem> cartItems,
    required double totalAmount,
    String paymentType = 'cash',
    int? customerId,
    required String userRole,
  }) async {
    final db = await _dbHelper.db;

    // 🔹 تحديد قيمة showForTax بناءً على المنطق المطلوب
    int showForTax;

    if (userRole == 'tax') {
      showForTax = 1;
      log('🎯 مستخدم ضريبي - الفاتورة مضمنة بالضرائب');
    } else {
      final settings = await db.query('settings', limit: 1);
      if (settings.isNotEmpty) {
        dynamic taxSetting = settings.first['defaultTaxSetting'];
        if (taxSetting is String) {
          showForTax = int.tryParse(taxSetting) ?? 0;
        } else if (taxSetting is int) {
          showForTax = taxSetting;
        } else {
          showForTax = 0;
        }
      } else {
        showForTax = 0;
      }
      log('🎯 إعداد افتراضي - showForTax: $showForTax');
    }

    // التحقق من الكميات قبل بدء المعاملة (للمنتجات فقط، ليس للخدمات)
    for (var item in cartItems) {
      // تخطي الخدمات (ليس لها مخزون)
      if (item.isService) {
        continue;
      }

      final product = item.product;
      if (product == null) {
        throw Exception('المنتج غير موجود');
      }

      // جلب الكمية الحالية من قاعدة البيانات كـ REAL
      final List<Map<String, dynamic>> result = await db.query(
        'products',
        columns: ['quantity', 'name'],
        where: 'id = ?',
        whereArgs: [product.id],
      );

      if (result.isNotEmpty) {
        // التعامل مع الكمية كـ REAL
        final dynamic quantityValue = result.first['quantity'];
        final double currentQuantity =
            (quantityValue is int)
                ? quantityValue.toDouble()
                : quantityValue as double;

        final String productName = result.first['name'] as String;

        // حساب الكمية المطلوبة بالوحدة الأساسية
        double requiredQuantity = item.quantity;
        if (item.selectedUnit != null) {
          requiredQuantity = item.quantity * item.selectedUnit!.containQty;
        }

        if (currentQuantity < requiredQuantity) {
          throw Exception(
            'المنتج "$productName" لا يوجد به كمية كافية. '
            'الكمية المتاحة: ${currentQuantity.toStringAsFixed(2)} ${translateUnit(product.baseUnit)}',
          );
        }
      } else {
        throw Exception('المنتج غير موجود في قاعدة البيانات');
      }
    }

    // إذا كل المنتجات كافية، نكمل العملية
    await db.transaction((txn) async {
      // 1️⃣ إضافة صف في جدول sales مع حقل showForTax
      final saleId = await txn.insert('sales', {
        'date': DateTime.now().toIso8601String(),
        'total_amount': totalAmount,
        'total_profit': 0.0,
        'customer_id': customerId,
        'payment_type': paymentType,
        'show_for_tax': showForTax,
      });

      double totalProfit = 0.0;

      // 2️⃣ إضافة العناصر المرتبطة في sale_items
      for (var item in cartItems) {
        if (item.isService) {
          // معالجة الخدمة
          final double actualPrice = item.unitPrice;
          final double subtotal = item.totalPrice;
          final double profit = 0.0; // الخدمات ليس لها ربح

          totalProfit += profit;

          // إدراج الخدمة في sale_items
          await txn.insert('sale_items', {
            'sale_id': saleId,
            'product_id': null, // الخدمات ليس لها product_id
            'unit_id': null,
            'quantity': item.quantity,
            'unit_type': 'service', // نوع خاص للخدمات
            'custom_unit_name': item.serviceName, // اسم الخدمة
            'price': actualPrice,
            'cost_price': 0.0, // الخدمات ليس لها تكلفة
            'subtotal': subtotal,
            'profit': profit, // ربح = 0
          });

          log(
            '✅ تم إضافة خدمة: ${item.serviceName} - السعر: $actualPrice (ربح: 0)',
          );
        } else {
          // معالجة المنتج (الكود الأصلي)
          final product = item.product;
          if (product == null) {
            throw Exception('المنتج غير موجود');
          }

          final double costPrice = product.costPrice;

          // استخدام سعر الوحدة المختارة إذا كانت موجودة
          double actualPrice = item.unitPrice;
          int? unitId = item.selectedUnit?.id;

          // تحديد نوع الوحدة واسمها
          String unitType;
          String? customUnitName;

          if (item.selectedUnit != null) {
            // إذا كانت وحدة مخصصة
            unitType = 'custom';
            customUnitName = item.selectedUnit!.unitName;
          } else {
            // إذا كانت الوحدة الأساسية
            unitType = product.baseUnit;
            customUnitName = null;
          }

          final double subtotal = item.totalPrice;
          final double profit = (actualPrice - costPrice) * item.quantity;

          totalProfit += profit;

          // إدراج العنصر مع معلومات الوحدة
          await txn.insert('sale_items', {
            'sale_id': saleId,
            'product_id': product.id,
            'unit_id': unitId,
            'quantity': item.quantity,
            'unit_type': unitType,
            'custom_unit_name': customUnitName,
            'price': actualPrice,
            'cost_price': costPrice,
            'subtotal': subtotal,
            'profit': profit,
          });

          // 3️⃣ خصم الكمية من المخزون بالوحدة الأساسية (للمنتجات فقط)
          double quantityToDeduct = item.quantity;

          if (item.selectedUnit != null) {
            // تحويل الكمية إلى الوحدة الأساسية
            quantityToDeduct = item.quantity * item.selectedUnit!.containQty;
          }

          await txn.rawUpdate(
            '''
        UPDATE products 
        SET quantity = quantity - ?
        WHERE id = ?
        ''',
            [quantityToDeduct, product.id],
          );

          log(
            '📦 تم خصم ${quantityToDeduct.toStringAsFixed(2)} ${product.baseUnit} من منتج ${product.name}',
          );
        }
      }

      // 4️⃣ تحديث إجمالي الربح في جدول sales
      await txn.update(
        'sales',
        {'total_profit': totalProfit},
        where: 'id = ?',
        whereArgs: [saleId],
      );

      log('💰 إجمالي الربح في الفاتورة: $totalProfit');
    });

    log('✅ تم إضافة الفاتورة بنجاح - showForTax: $showForTax');
    notifyListeners();
  }

  // جلب منتج بواسطة الـ ID
  // في ProductProvider.dart - تحديث دالة getProductById
  Future<Product?> getProductById(int id) async {
    try {
      final db = await _dbHelper.db;
      final result = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (result.isEmpty) {
        return null;
      }

      final map = result.first;
      final product = Product(
        id: map['id'] as int?,
        name: map['name'] as String,
        barcode: map['barcode'] as String?,
        baseUnit: map['base_unit'] as String? ?? 'piece',
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
        costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0.0,
        addedDate: map['added_date'] as String?,
        hasExpiry: map['has_expiry'] == 1,
        // ⬅️ إضافة الحقول الجديدة
        hasExpiryDate: (map['has_expiry_date'] as int?) == 1,
        active: (map['active'] as int?) != 0, // Default to true if null
      );

      return product;
    } catch (e) {
      log('Error getting product by ID: $e');
      return null;
    }
  }

  // في ProductProvider.dart
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

  // في ProductProvider.dart
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

  Future<void> updateSale({
    required Sale originalSale,
    required List<CartItem> cartItems,
    required double totalAmount,
    required String userRole,
  }) async {
    final db = await _dbHelper.db;

    int showForTax = await _determineShowForTax(userRole, db);

    final double oldTotal = originalSale.totalAmount;
    final double difference = totalAmount - oldTotal;

    await db.transaction((txn) async {
      // 1️⃣ تحديث بيانات الفاتورة الرئيسية مبدئيًا
      await txn.update(
        'sales',
        {
          'total_amount': totalAmount,
          'total_profit': 0.0,
          'show_for_tax': showForTax,
        },
        where: 'id = ?',
        whereArgs: [originalSale.id],
      );

      // 2️⃣ جلب العناصر الأصلية من الفاتورة
      final originalItems = await txn.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [originalSale.id],
      );

      // 3️⃣ إرجاع الكميات القديمة إلى المخزون أولاً
      for (var originalItem in originalItems) {
        final int productId = originalItem['product_id'] as int;
        final double originalQuantity =
            (originalItem['quantity'] is int)
                ? (originalItem['quantity'] as int).toDouble()
                : originalItem['quantity'] as double;
        final String unitType = originalItem['unit_type'] as String;
        final int? unitId = originalItem['unit_id'] as int?;

        double quantityToReturn = originalQuantity;

        if (unitType == 'custom' && unitId != null) {
          final unitResult = await txn.query(
            'product_units',
            columns: ['contain_qty'],
            where: 'id = ?',
            whereArgs: [unitId],
          );
          if (unitResult.isNotEmpty) {
            final double containQty =
                (unitResult.first['contain_qty'] is int)
                    ? (unitResult.first['contain_qty'] as int).toDouble()
                    : unitResult.first['contain_qty'] as double;
            quantityToReturn = originalQuantity * containQty;
          }
        }

        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity + ? WHERE id = ?',
          [quantityToReturn, productId],
        );
      }

      // 3.1️⃣ تحقق من المخزون بعد إرجاع القديم
      await _validateStockQuantities(cartItems, txn);

      double totalProfit = 0.0;

      // 4️⃣ حذف العناصر القديمة
      await txn.delete(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [originalSale.id],
      );

      // 5️⃣ إضافة العناصر الجديدة وخصم المخزون
      for (var item in cartItems) {
        if (item.quantity == 0) continue;

        final product = item.product;
        final double costPrice = product!.costPrice;
        double actualPrice = item.selectedUnit?.sellPrice ?? product.price;
        int? unitId = item.selectedUnit?.id;

        String unitType;
        String? customUnitName;

        if (item.selectedUnit != null) {
          unitType = 'custom';
          customUnitName = item.selectedUnit!.unitName;
        } else {
          unitType = product!.baseUnit;
          customUnitName = null;
        }

        final double subtotal = actualPrice * item.quantity;
        final double profit = (actualPrice - costPrice) * item.quantity;
        totalProfit += profit;

        Map<String, dynamic> saleItemData = {
          'sale_id': originalSale.id,
          'product_id': product?.id,
          'unit_id': unitId,
          'quantity': item.quantity,
          'unit_type': unitType,
          'custom_unit_name': customUnitName,
          'price': actualPrice,
          'cost_price': costPrice,
          'subtotal': subtotal,
          'profit': profit,
        };
        saleItemData.removeWhere((key, value) => value == null);

        await txn.insert('sale_items', saleItemData);

        // خصم المخزون
        double quantityToDeduct = item.quantity;
        if (item.selectedUnit != null) {
          quantityToDeduct = item.quantity * item.selectedUnit!.containQty;
        }
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity - ? WHERE id = ?',
          [quantityToDeduct, product?.id],
        );
      }

      // 6️⃣ تحديث إجمالي الربح
      await txn.update(
        'sales',
        {'total_profit': totalProfit},
        where: 'id = ?',
        whereArgs: [originalSale.id],
      );

      // 7️⃣ تعديل دين الزبون بالفرق فقط
      if (originalSale.paymentType == 'credit' &&
          originalSale.customerId != null &&
          difference != 0) {
        await txn.rawUpdate(
          '''
        UPDATE customer_balance
        SET balance = balance + ?, last_updated = ?
        WHERE customer_id = ?
        ''',
          [
            difference,
            DateTime.now().toIso8601String(),
            originalSale.customerId,
          ],
        );
      }
    });

    notifyListeners();
  }

  // الدوال المساعدة التي تعمل مع Database فقط (ليس Transaction)
  Future<int> _determineShowForTax(String userRole, Database db) async {
    if (userRole == 'tax') {
      log('🎯 مستخدم ضريبي - الفاتورة مضمنة بالضرائب');
      return 1;
    } else {
      final settings = await db.query('settings', limit: 1);
      if (settings.isNotEmpty) {
        dynamic taxSetting = settings.first['defaultTaxSetting'];
        if (taxSetting is String) {
          return int.tryParse(taxSetting) ?? 0;
        } else if (taxSetting is int) {
          return taxSetting;
        }
      }
      return 0;
    }
  }

  Future<void> _validateStockQuantities(
    List<CartItem> cartItems,
    DatabaseExecutor db, // ✅ بدل Database
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

  // في ProductProvider.dart
}
