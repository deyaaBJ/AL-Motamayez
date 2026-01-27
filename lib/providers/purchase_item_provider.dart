import 'package:flutter/material.dart';
import 'package:motamayez/utils/formatters.dart' show Formatters;
import '../db/db_helper.dart';
import 'dart:developer';

class PurchaseItemProvider with ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  // إضافة عنصر شراء + تحديث المخزون (نسخة معدلة لدعم الوحدات)
  Future<void> addPurchaseItem({
    required int purchaseId,
    required int productId,
    required double quantity, // الكمية الفعلية (القطع)
    required double
    costPrice, // سعر تكلفة القطعة الواحدة (تم حسابها في _addItem)
    bool isUnit = false,
    int? unitId,
    double unitContainQty = 1.0,
  }) async {
    final db = await _dbHelper.db;

    await db.transaction((txn) async {
      double displayQuantity = quantity;

      if (isUnit && unitContainQty > 1) {
        displayQuantity = quantity / unitContainQty; // عدد الوحدات
      }

      // 1️⃣ إضافة عنصر الفاتورة مع معلومات الوحدة
      // ⬅️ مش محتاج unit_cost_price، بس cost_price (سعر القطعة الواحدة)
      await txn.insert('purchase_items', {
        'purchase_id': purchaseId,
        'product_id': productId,
        'quantity': quantity, // الكمية الفعلية (القطع)
        'cost_price': costPrice, // سعر تكلفة القطعة الواحدة (هذا فقط)
        'subtotal': quantity * costPrice,
        'unit_id': unitId, // حفظ معرف الوحدة
        'display_quantity': displayQuantity,
      });

      // 2️⃣ جلب بيانات المنتج الحالية
      final productResult = await txn.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (productResult.isEmpty) {
        throw Exception('المنتج غير موجود');
      }

      final product = productResult.first;
      final oldQty = (product['quantity'] as num).toDouble();
      final oldCost = (product['cost_price'] as num).toDouble();

      // 3️⃣ حساب المتوسط المرجح للتكلفة
      final totalOldCost = oldQty * oldCost;
      final totalNewCost =
          quantity * costPrice; // ⬅️ نستخدم costPrice (سعر القطعة)
      final totalQty = oldQty + quantity;

      // حساب متوسط التكلفة الجديد
      double newAverageCost = costPrice;

      if (totalQty > 0) {
        newAverageCost = (totalOldCost + totalNewCost) / totalQty;
      }

      // تحديث المنتج بالكمية الفعلية ومتوسط السعر الجديد
      await txn.update(
        'products',
        {'quantity': totalQty, 'cost_price': newAverageCost},
        where: 'id = ?',
        whereArgs: [productId],
      );

      // 4️⃣ تسجيل المعلومات في اللوغ للمراقبة
      log('''
    📊 عملية شراء منتج:
    المنتج ID: $productId
    -------------------------
    معلومات الشراء:
    - الكمية الفعلية: $quantity قطعة
    - سعر تكلفة القطعة: ${Formatters.formatCurrency(costPrice)}
    - إجمالي التكلفة: ${Formatters.formatCurrency(totalNewCost)}
    -------------------------
    المخزون السابق:
    - الكمية: $oldQty قطعة
    - متوسط السعر: ${Formatters.formatCurrency(oldCost)}
    -------------------------
    المخزون الجديد:
    - الكمية: $totalQty قطعة
    - متوسط السعر: ${Formatters.formatCurrency(newAverageCost)}
    ''');
    });

    notifyListeners();
  }

  // في PurchaseItemProvider، أضف هذه الدالة:
  Future<void> updateUnitSellPrice({
    required int unitId,
    required double newSellPrice,
  }) async {
    final db = await _dbHelper.db;

    try {
      await db.update(
        'product_units',
        {'sell_price': newSellPrice},
        where: 'id = ?',
        whereArgs: [unitId],
      );

      log(
        '✅ تم تحديث سعر بيع الوحدة ID: $unitId إلى ${Formatters.formatCurrency(newSellPrice)}',
      );
    } catch (e) {
      log('❌ خطأ في تحديث سعر الوحدة: $e');
    }
  }

  // دالة لحساب سعر بيع الوحدة المقترح بناءً على متوسط السعر
  Future<double> calculateSuggestedUnitPrice({
    required int productId,
    required int unitId,
  }) async {
    final db = await _dbHelper.db;

    try {
      // جلب متوسط سعر تكلفة المنتج
      final productResult = await db.query(
        'products',
        columns: ['cost_price'],
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (productResult.isEmpty) {
        return 0.0;
      }

      final avgCostPrice =
          (productResult.first['cost_price'] as num).toDouble();

      // جلب عدد القطع في الوحدة
      final unitResult = await db.query(
        'product_units',
        columns: ['contain_qty'],
        where: 'id = ?',
        whereArgs: [unitId],
      );

      if (unitResult.isEmpty) {
        return 0.0;
      }

      final containQty = (unitResult.first['contain_qty'] as num).toDouble();

      // حساب سعر الوحدة المقترح: متوسط السعر × عدد القطع × نسبة ربح (مثلاً 20%)
      final suggestedPrice = avgCostPrice * containQty * 1.2;

      log(
        '💰 سعر الوحدة المقترح: ${Formatters.formatCurrency(avgCostPrice)} × $containQty × 1.2 = ${Formatters.formatCurrency(suggestedPrice)}',
      );

      return suggestedPrice;
    } catch (e) {
      log('❌ خطأ في حساب سعر الوحدة المقترح: $e');
      return 0.0;
    }
  }

  // جلب عناصر فاتورة شراء مع معلومات المنتج
  Future<List<Map<String, dynamic>>> getPurchaseItems(int purchaseId) async {
    final db = await _dbHelper.db;
    try {
      return await db.query(
        'purchase_items',
        where: 'purchase_id = ?',
        whereArgs: [purchaseId],
      );
    } catch (e) {
      log('Error getting purchase items: $e');
      return [];
    }
  }

  // جلب عناصر فاتورة شراء مع معلومات المنتج والوحدة
  Future<List<Map<String, dynamic>>> getPurchaseItemsWithProducts(
    int purchaseId,
  ) async {
    final db = await _dbHelper.db;
    try {
      return await db.rawQuery(
        '''
      SELECT 
        pi.*,
        p.name as product_name,
        p.barcode as product_barcode,
        p.base_unit,
        p.quantity as current_stock,
        pu.unit_name,
        pu.barcode as unit_barcode,
        pu.contain_qty,
        pu.sell_price as unit_sell_price,
        CASE 
          WHEN pi.unit_id IS NOT NULL THEN pu.unit_name
          ELSE p.base_unit
        END as display_unit,
        CASE 
          WHEN pi.unit_id IS NOT NULL AND pi.display_quantity IS NOT NULL 
            THEN pi.display_quantity
          ELSE pi.quantity
        END as display_quantity
      FROM purchase_items pi
      LEFT JOIN products p ON p.id = pi.product_id
      LEFT JOIN product_units pu ON pu.id = pi.unit_id
      WHERE pi.purchase_id = ?
      ORDER BY pi.id DESC
    ''',
        [purchaseId],
      );
    } catch (e) {
      log('Error getting purchase items with products: $e');
      return [];
    }
  }

  // حذف عنصر شراء
  Future<void> deletePurchaseItem(int itemId) async {
    final db = await _dbHelper.db;

    await db.transaction((txn) async {
      // جلب بيانات العنصر أولاً
      final items = await txn.query(
        'purchase_items',
        where: 'id = ?',
        whereArgs: [itemId],
      );

      if (items.isEmpty) return;

      final item = items.first;
      final productId = item['product_id'] as int;
      final quantity = (item['quantity'] as num).toDouble();
      final unitId = item['unit_id'] as int?;

      // حذف العنصر من الفاتورة
      await txn.delete('purchase_items', where: 'id = ?', whereArgs: [itemId]);

      // نقص الكمية من المخزون (لأننا نحذف فاتورة شراء)
      await txn.rawUpdate(
        '''
        UPDATE products 
        SET quantity = quantity - ?
        WHERE id = ?
        ''',
        [quantity, productId],
      );

      // تسجيل في اللوغ
      log(
        '🗑️ تم حذف عنصر الشراء ID: $itemId, المنتج ID: $productId, الكمية: $quantity',
      );
      if (unitId != null) {
        log('🗑️ الوحدة المرتبطة ID: $unitId');
      }
    });

    notifyListeners();
  }

  // دالة مساعدة: حساب متوسط سعر المنتج بعدة عمليات شراء
  Future<double> calculateAverageCost(int productId) async {
    final db = await _dbHelper.db;

    try {
      // جلب جميع عمليات شراء المنتج
      final purchases = await db.rawQuery(
        '''
        SELECT SUM(quantity) as total_qty, SUM(quantity * cost_price) as total_cost
        FROM purchase_items
        WHERE product_id = ?
      ''',
        [productId],
      );

      if (purchases.isEmpty || purchases.first['total_qty'] == null) {
        return 0.0;
      }

      final totalQty = purchases.first['total_qty'] as double;
      final totalCost = purchases.first['total_cost'] as double;

      if (totalQty > 0) {
        return totalCost / totalQty;
      }

      return 0.0;
    } catch (e) {
      log('Error calculating average cost: $e');
      return 0.0;
    }
  }

  // دالة مساعدة: تحديث مخزون المنتج مباشرة (مفيدة للإصلاحات)
  Future<void> updateProductStockDirectly({
    required int productId,
    required double quantityChange,
    double? newCostPrice,
  }) async {
    final db = await _dbHelper.db;

    await db.transaction((txn) async {
      // جلب المنتج الحالي
      final productResult = await txn.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (productResult.isEmpty) {
        throw Exception('المنتج غير موجود');
      }

      final product = productResult.first;
      final currentQty = (product['quantity'] as num).toDouble();
      final currentCost = (product['cost_price'] as num).toDouble();

      // حساب القيم الجديدة
      final newQuantity = currentQty + quantityChange;
      double newAverageCost = currentCost;

      // إذا تم تقديم سعر تكلفة جديد، نحسب المتوسط
      if (newCostPrice != null && quantityChange > 0) {
        final currentTotal = currentQty * currentCost;
        final newTotal = quantityChange * newCostPrice;
        final totalCost = currentTotal + newTotal;
        newAverageCost = totalCost / newQuantity;
      }

      // تحديث المنتج
      await txn.update(
        'products',
        {'quantity': newQuantity, 'cost_price': newAverageCost},
        where: 'id = ?',
        whereArgs: [productId],
      );

      log('✅ تم تحديث مخزون المنتج ID: $productId');
      log('🔢 الكمية الجديدة: $newQuantity (التغيير: $quantityChange)');
      log('💰 متوسط السعر الجديد: $newAverageCost');
    });

    notifyListeners();
  }
}
