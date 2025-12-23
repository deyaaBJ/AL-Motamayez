import 'package:flutter/material.dart';
import '../db/db_helper.dart';

class PurchaseItemProvider with ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  // إضافة عنصر شراء + تحديث المخزون
  Future<void> addPurchaseItem({
    required int purchaseId,
    required int productId,
    required double quantity,
    required double costPrice,
  }) async {
    final db = await _dbHelper.db;

    await db.transaction((txn) async {
      // 1️⃣ إضافة عنصر الفاتورة
      await txn.insert('purchase_items', {
        'purchase_id': purchaseId,
        'product_id': productId,
        'quantity': quantity,
        'cost_price': costPrice,
        'subtotal': quantity * costPrice,
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
      final totalNewCost = quantity * costPrice;
      final totalQty = oldQty + quantity;

      // حساب متوسط التكلفة الجديد
      final newCost =
          totalQty > 0 ? (totalOldCost + totalNewCost) / totalQty : costPrice;

      // 4️⃣ تحديث المنتج - زيادة المخزون وتحديث التكلفة
      await txn.update(
        'products',
        {
          'quantity': oldQty + quantity, // زيادة الكمية
          'cost_price': newCost, // تحديث متوسط التكلفة
        },
        where: 'id = ?',
        whereArgs: [productId],
      );
    });

    notifyListeners();
  }

  // جلب عناصر فاتورة شراء
  Future<List<Map<String, dynamic>>> getPurchaseItems(int purchaseId) async {
    final db = await _dbHelper.db;
    try {
      return await db.query(
        'purchase_items',
        where: 'purchase_id = ?',
        whereArgs: [purchaseId],
      );
    } catch (e) {
      print('Error getting purchase items: $e');
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
    });

    notifyListeners();
  }

  // في providers/purchase_item_provider.dart
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
        p.barcode,
        p.base_unit,
        p.quantity as current_stock
      FROM purchase_items pi
      JOIN products p ON p.id = pi.product_id
      WHERE pi.purchase_id = ?
      ORDER BY pi.id DESC
    ''',
        [purchaseId],
      );
    } catch (e) {
      print('Error getting purchase items with products: $e');
      return [];
    }
  }
}
