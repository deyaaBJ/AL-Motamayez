import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:motamayez/db/db_helper.dart';

class OpeningBalanceProvider with ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  Future<int> addOpeningBalance({
    required DateTime date,
    String? note,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await _dbHelper.db;
    int openingBalanceId = 0;

    await db.transaction((txn) async {
      openingBalanceId = await txn.insert('opening_balances', {
        'movement_type': 'opening_balance',
        'date': date.toIso8601String(),
        'note': note?.trim().isEmpty == true ? null : note?.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      for (final item in items) {
        final int productId = item['product_id'] as int;
        final double quantity = (item['quantity'] as num).toDouble();
        final double costPrice = (item['cost_price'] as num).toDouble();
        final double subtotal =
            (item['subtotal'] as num?)?.toDouble() ?? (quantity * costPrice);

        await txn.insert('opening_balance_items', {
          'opening_balance_id': openingBalanceId,
          'product_id': productId,
          'quantity': quantity,
          'cost_price': costPrice,
          'subtotal': subtotal,
        });

        final productResult = await txn.query(
          'products',
          columns: ['quantity', 'cost_price', 'has_expiry_date'],
          where: 'id = ?',
          whereArgs: [productId],
          limit: 1,
        );

        if (productResult.isEmpty) {
          throw Exception('المنتج غير موجود');
        }

        final product = productResult.first;
        final double oldQty = (product['quantity'] as num?)?.toDouble() ?? 0.0;
        final double oldCost =
            (product['cost_price'] as num?)?.toDouble() ?? 0.0;
        final double totalQty = oldQty + quantity;
        final double newAverageCost =
            totalQty > 0
                ? ((oldQty * oldCost) + (quantity * costPrice)) / totalQty
                : costPrice;

        await txn.update(
          'products',
          {'quantity': totalQty, 'cost_price': newAverageCost},
          where: 'id = ?',
          whereArgs: [productId],
        );

        final bool hasExpiryDate = (product['has_expiry_date'] as int?) == 1;
        final String? providedExpiryDate = item['expiry_date'] as String?;

        if (hasExpiryDate &&
            (providedExpiryDate == null || providedExpiryDate.trim().isEmpty)) {
          throw Exception('يجب تحديد تاريخ الانتهاء للمنتج قبل الحفظ');
        }

        final String batchExpiry =
            hasExpiryDate ? providedExpiryDate! : '2099-12-31';

        await txn.insert('product_batches', {
          'product_id': productId,
          'purchase_item_id': null,
          'quantity': quantity,
          'remaining_quantity': quantity,
          'cost_price': costPrice,
          'production_date': null,
          'expiry_date': batchExpiry,
          'active': 1,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });

    log('Saved opening balance #$openingBalanceId');
    notifyListeners();
    return openingBalanceId;
  }
}
