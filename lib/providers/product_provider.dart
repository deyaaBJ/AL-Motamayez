import 'package:flutter/material.dart';
import 'package:shopmate/models/cart_item.dart';
import 'package:shopmate/models/product.dart';
import 'package:shopmate/models/product_unit.dart';
import 'package:shopmate/models/sale.dart';
import 'package:shopmate/models/sale_item.dart';
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

  Future<List<Product>> searchProductsByBarcode(String barcode) async {
    final db = await _dbHelper.db;

    final result = await db.query(
      'products',
      where: 'barcode = ?', // 🔹 مطابقة كاملة
      whereArgs: [barcode], // لا نضع % لأنها للبحث الجزئي
    );

    return result.map((map) => Product.fromMap(map)).toList();
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
      print('Error getting product units: $e');
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
  Future<List<ProductUnit>> searchProductUnitsByBarcode(String barcode) async {
    final db = await _dbHelper.db;
    final result = await db.query(
      'product_units',
      where: 'barcode LIKE ?',
      whereArgs: ['%$barcode%'],
    );
    return result.map((map) => ProductUnit.fromMap(map)).toList();
  }

  Future<void> addProduct(Product product) async {
    final db = await _dbHelper.db;

    // استخدام الهيكل الجديد
    final productMap = {
      'name': product.name,
      'barcode': product.barcode,
      'base_unit': product.baseUnit,
      'price': product.price,
      'quantity': product.quantity,
      'cost_price': product.costPrice,
    };

    final id = await db.insert('products', productMap);

    // إضافة المنتج للقائمة المحلية مع الهيكل الجديد
    _products.add(
      Product(
        id: id,
        name: product.name,
        barcode: product.barcode,
        baseUnit: product.baseUnit,
        price: product.price,
        quantity: product.quantity,
        costPrice: product.costPrice,
      ),
    );

    notifyListeners();
  }

  Future<void> updateProduct(Product updatedProduct) async {
    final db = await _dbHelper.db;

    // ✅ إنشاء map للتحديث مع القيم الجديدة فقط
    final updateData = <String, dynamic>{};

    if (updatedProduct.name.isNotEmpty) {
      updateData['name'] = updatedProduct.name;
    }

    if (updatedProduct.price > 0) {
      updateData['price'] = updatedProduct.price;
    }

    if (updatedProduct.costPrice > 0) {
      updateData['cost_price'] = updatedProduct.costPrice;
    }

    // ✅ الكمية يتم تحديثها دائماً (تم حسابها في الواجهة)
    updateData['quantity'] = updatedProduct.quantity;

    // ✅ الحقول الجديدة - استخدام base_unit بدلاً من unit
    if (updatedProduct.baseUnit.isNotEmpty) {
      updateData['base_unit'] = updatedProduct.baseUnit;
    }

    // ❌ إزالة الحقول القديمة التي لم تعد موجودة في الجدول الجديد
    // updateData['allow_pack'] = updatedProduct.allowPack;
    // updateData['pack_price'] = updatedProduct.packPrice;
    // updateData['pack_size'] = updatedProduct.packSize;

    // تحديث قاعدة البيانات
    await db.update(
      'products',
      updateData,
      where: 'barcode = ?',
      whereArgs: [updatedProduct.barcode],
    );

    // ✅ تحديث القائمة المحلية
    final index = _products.indexWhere(
      (p) => p.barcode == updatedProduct.barcode,
    );
    if (index != -1) {
      // تحديث المنتج في القائمة المحلية مع الهيكل الجديد
      _products[index] = Product(
        id: _products[index].id,
        name:
            updatedProduct.name.isNotEmpty
                ? updatedProduct.name
                : _products[index].name,
        barcode: _products[index].barcode,
        baseUnit:
            updatedProduct.baseUnit.isNotEmpty
                ? updatedProduct.baseUnit
                : _products[index].baseUnit,
        price:
            updatedProduct.price > 0
                ? updatedProduct.price
                : _products[index].price,
        costPrice:
            updatedProduct.costPrice > 0
                ? updatedProduct.costPrice
                : _products[index].costPrice,
        quantity: updatedProduct.quantity,
        addedDate: _products[index].addedDate,
      );
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
    String paymentType = 'cash',
    int? customerId,
    required String userRole,
  }) async {
    final db = await _dbHelper.db;

    // 🔹 تحديد قيمة showForTax بناءً على المنطق المطلوب
    int showForTax;

    if (userRole == 'tax') {
      showForTax = 1;
      print('🎯 مستخدم ضريبي - الفاتورة مضمنة بالضرائب');
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
      print('🎯 إعداد افتراضي - showForTax: $showForTax');
    }

    // التحقق من الكميات قبل بدء المعاملة
    for (var item in cartItems) {
      final product = item.product;

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
            'المنتج "$productName" لا يوجد به كمية كافية. الكمية المتاحة: ${currentQuantity.toStringAsFixed(2)} ${product.baseUnit}',
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
        final product = item.product;
        final double costPrice = product.costPrice ?? 0.0;

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
          unitType = product.baseUnit; // 'piece' أو 'kg'
          customUnitName = null;
        }

        final double subtotal = item.totalPrice;
        final double profit = (actualPrice - costPrice) * item.quantity;

        totalProfit += profit;

        // إدراج العنصر مع معلومات الوحدة
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': product.id,
          'unit_id': unitId, // يمكن أن يكون null إذا بيع بالوحدة الأساسية
          'quantity': item.quantity,
          'unit_type': unitType, // ⬅️ هذا الحقل كان ناقص
          'custom_unit_name': customUnitName, // ⬅️ وهذا أيضاً كان ناقص
          'price': actualPrice,
          'cost_price': costPrice,
          'subtotal': subtotal,
          'profit': profit,
        });

        // 3️⃣ خصم الكمية من المخزون بالوحدة الأساسية
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

        print(
          '📦 تم خصم ${quantityToDeduct.toStringAsFixed(2)} ${product.baseUnit} من منتج ${product.name}',
        );
      }

      // 4️⃣ تحديث إجمالي الربح في جدول sales
      await txn.update(
        'sales',
        {'total_profit': totalProfit},
        where: 'id = ?',
        whereArgs: [saleId],
      );

      print('💰 إجمالي الربح في الفاتورة: $totalProfit');
    });

    print('✅ تم إضافة الفاتورة بنجاح - showForTax: $showForTax');
    notifyListeners();
  }

  // في ProductProvider.dart

  // جلب منتج بواسطة الـ ID
  Future<Product?> getProductById(int id) async {
    try {
      final db = await _dbHelper.db;
      final result = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [id],
      );
      return result.isNotEmpty ? Product.fromMap(result.first) : null;
    } catch (e) {
      print('Error getting product by ID: $e');
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
      print('Error searching products by name: $e');
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
      print('Error searching product units by name: $e');
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
      print('Error getting sale items: $e');
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

    // 🔹 تحديد قيمة showForTax
    int showForTax = await _determineShowForTax(userRole, db);

    // التحقق من الكميات المتاحة
    await _validateStockQuantities(cartItems, db);

    await db.transaction((txn) async {
      // 1️⃣ تحديث بيانات الفاتورة الرئيسية
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

      // 3️⃣ إرجاع الكميات الأصلية إلى المخزون أولاً
      for (var originalItem in originalItems) {
        final int productId = originalItem['product_id'] as int;
        final double originalQuantity =
            (originalItem['quantity'] is int)
                ? (originalItem['quantity'] as int).toDouble()
                : originalItem['quantity'] as double;
        final String unitType = originalItem['unit_type'] as String;
        final int? unitId = originalItem['unit_id'] as int?;

        double quantityToReturn = originalQuantity;

        // إذا كانت وحدة مخصصة، نحتاج لمعرفة معامل التحويل
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

        // إرجاع الكمية إلى المخزون
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity + ? WHERE id = ?',
          [quantityToReturn, productId],
        );

        print(
          '🔄 تم إرجاع ${quantityToReturn.toStringAsFixed(2)} إلى المخزون للمنتج ID: $productId',
        );
      }

      double totalProfit = 0.0;

      // 4️⃣ حذف العناصر القديمة
      await txn.delete(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [originalSale.id],
      );

      // 5️⃣ إضافة العناصر الجديدة
      for (var item in cartItems) {
        if (item.quantity == 0) continue;

        final product = item.product;
        final double costPrice = product.costPrice ?? 0.0;

        double actualPrice = item.selectedUnit?.sellPrice ?? product.price;
        int? unitId = item.selectedUnit?.id;

        String unitType;
        String? customUnitName;

        if (item.selectedUnit != null) {
          unitType = 'custom';
          customUnitName = item.selectedUnit!.unitName;
        } else {
          unitType = product.baseUnit;
          customUnitName = null;
        }

        final double subtotal = actualPrice * item.quantity;
        final double profit = (actualPrice - costPrice) * item.quantity;

        totalProfit += profit;

        Map<String, dynamic> saleItemData = {
          'sale_id': originalSale.id,
          'product_id': product.id,
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

        // 6️⃣ خصم الكميات الجديدة من المخزون
        double quantityToDeduct = item.quantity;
        if (item.selectedUnit != null) {
          quantityToDeduct = item.quantity * item.selectedUnit!.containQty;
        }

        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity - ? WHERE id = ?',
          [quantityToDeduct, product.id],
        );

        print(
          '📦 تم خصم ${quantityToDeduct.toStringAsFixed(2)} ${product.baseUnit} من منتج ${product.name}',
        );
      }

      // 7️⃣ تحديث إجمالي الربح
      await txn.update(
        'sales',
        {'total_profit': totalProfit},
        where: 'id = ?',
        whereArgs: [originalSale.id],
      );

      print('💰 إجمالي الربح في الفاتورة بعد التعديل: $totalProfit');
    });

    print(
      '✅ تم تحديث الفاتورة #${originalSale.id} بنجاح - showForTax: $showForTax',
    );
    notifyListeners();
  }

  // الدوال المساعدة التي تعمل مع Database فقط (ليس Transaction)
  Future<int> _determineShowForTax(String userRole, Database db) async {
    if (userRole == 'tax') {
      print('🎯 مستخدم ضريبي - الفاتورة مضمنة بالضرائب');
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
    Database db,
  ) async {
    for (var item in cartItems) {
      final product = item.product;

      final List<Map<String, dynamic>> result = await db.query(
        'products',
        columns: ['quantity', 'name'],
        where: 'id = ?',
        whereArgs: [product.id],
      );

      if (result.isNotEmpty) {
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

        if (requiredQuantity > 0 && currentQuantity < requiredQuantity) {
          throw Exception(
            'المنتج "$productName" لا يوجد به كمية كافية. الكمية المتاحة: ${currentQuantity.toStringAsFixed(2)} ${product.baseUnit}',
          );
        }
      } else {
        throw Exception('المنتج غير موجود في قاعدة البيانات');
      }
    }
  }

  // في ProductProvider.dart
}
