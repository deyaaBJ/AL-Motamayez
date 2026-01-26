import 'package:flutter/material.dart';
import 'package:motamayez/db/db_helper.dart';

class ProductBatchProvider with ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  // دالة لإضافة دفعة جديدة
  Future<int> addProductBatch({
    required int productId,
    required int? purchaseItemId,
    required double quantity,
    required double remainingQuantity,
    required double costPrice,
    required String expiryDate,
    String? productionDate,
  }) async {
    try {
      final db = await _dbHelper.db;

      final batchId = await db.insert('product_batches', {
        'product_id': productId,
        'purchase_item_id': purchaseItemId,
        'quantity': quantity,
        'remaining_quantity': remainingQuantity,
        'cost_price': costPrice,
        'expiry_date': expiryDate,
        'production_date': productionDate,
        'created_at': DateTime.now().toIso8601String(),
      });

      return batchId;
    } catch (e) {
      print('خطأ في إضافة الدفعة: $e');
      rethrow;
    }
  }

  // دالة للحصول على الدفعات المتاحة لمنتج
  Future<List<Map<String, dynamic>>> getProductBatches(int productId) async {
    try {
      final db = await _dbHelper.db;

      final batches = await db.query(
        'product_batches',
        where: 'product_id = ? AND remaining_quantity > 0',
        whereArgs: [productId],
        orderBy: 'expiry_date ASC',
      );

      return batches;
    } catch (e) {
      print('خطأ في جلب الدفعات: $e');
      return [];
    }
  }
}
