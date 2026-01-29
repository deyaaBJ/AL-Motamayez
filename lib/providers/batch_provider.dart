// lib/providers/batch_provider.dart
import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:motamayez/models/batch_filter.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import '../db/db_helper.dart';
import '../models/batch.dart';

class BatchProvider with ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  // Pagination
  int _page = 0;
  final int _limit = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  BatchFilter? _currentFilter;

  // Lists
  List<Batch> _batches = [];
  List<Batch> get batches => _batches;

  int _totalBatches = 0;
  int get totalBatches => _totalBatches;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  bool get isLoading => _isLoadingMore;

  // إعادة تعيين حالة الـ pagination
  void resetPagination() {
    _page = 0;
    _hasMore = true;
    _isLoadingMore = false;
    _batches.clear();
  }

  // تحميل الدفعات مع JOIN على products
  Future<List<Batch>> loadBatches({
    bool reset = false,
    BatchFilter? filter,
  }) async {
    if (reset) {
      resetPagination();
    }

    if (filter != null) {
      _currentFilter = filter;
    }

    if (_isLoadingMore) return [];

    try {
      if (!reset) {
        _isLoadingMore = true;
        notifyListeners();
      } else {
        _isLoadingMore = true;
      }

      final db = await _dbHelper.db;

      // بناء الاستعلام مع JOIN
      String query = '''
        SELECT 
          pb.*,
          p.name as product_name,
          p.barcode as product_barcode,
          CASE 
            WHEN pb.expiry_date IS NULL THEN 9999
            ELSE julianday(pb.expiry_date) - julianday('now')
          END as days_remaining
        FROM product_batches pb
        LEFT JOIN products p ON pb.product_id = p.id
        WHERE pb.active = 1
      ''';

      final List<Object?> args = [];

      // تطبيق الفلاتر
      if (_currentFilter != null) {
        final filterClause = _currentFilter!.buildWhereClause(args);
        if (filterClause.isNotEmpty) {
          query += ' AND $filterClause';
        }
      }

      // ترتيب النتائج
      query += '''
        ORDER BY pb.expiry_date ASC
        LIMIT ? OFFSET ?
      ''';

      args.addAll([_limit, _page * _limit]);

      final result = await db.rawQuery(query, args);

      if (result.isEmpty) {
        _hasMore = false;
        if (reset) {
          _batches = [];
        }
      } else {
        // تحويل النتائج
        final newBatches =
            result.map((map) {
              return Batch.fromMap(
                map,
                productName: map['product_name'] as String?,
                productBarcode: map['product_barcode'] as String?,
              );
            }).toList();

        // تحديث الحالة
        _page++;

        if (newBatches.length < _limit) {
          _hasMore = false;
        }

        // إضافة الدفعات الجديدة للقائمة
        if (reset) {
          _batches = newBatches;
        } else {
          _batches.addAll(newBatches);
        }
      }

      // تحميل العدد الإجمالي
      await _loadTotalBatches();

      return _batches;
    } catch (e) {
      log('Error loading batches: $e');
      return [];
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // تحميل العدد الإجمالي
  Future<void> _loadTotalBatches() async {
    try {
      final db = await _dbHelper.db;

      String query = '''
        SELECT COUNT(*) as count
        FROM product_batches pb
        WHERE pb.active = 1
      ''';

      final List<Object?> args = [];

      if (_currentFilter != null) {
        final filterClause = _currentFilter!.buildWhereClause(args);
        if (filterClause.isNotEmpty) {
          query += ' AND $filterClause';
        }
      }

      final res = await db.rawQuery(query, args);

      if (res.isNotEmpty) {
        _totalBatches = (res.first['count'] as int?) ?? 0;
      } else {
        _totalBatches = 0;
      }
    } catch (e) {
      log('Error loading total batches: $e');
      _totalBatches = 0;
    }
  }

  // البحث عن دفعات
  Future<List<Batch>> searchBatches(String query) async {
    try {
      final db = await _dbHelper.db;

      final result = await db.rawQuery(
        '''
        SELECT 
          pb.*,
          p.name as product_name,
          p.barcode as product_barcode,
          CASE 
            WHEN pb.expiry_date IS NULL THEN 9999
            ELSE julianday(pb.expiry_date) - julianday('now')
          END as days_remaining
        FROM product_batches pb
        LEFT JOIN products p ON pb.product_id = p.id
        WHERE pb.active = 1 AND (p.name LIKE ? OR p.barcode LIKE ?)
        ORDER BY pb.expiry_date ASC
      ''',
        ['%$query%', '%$query%'],
      );

      return result.map((map) {
        return Batch.fromMap(
          map,
          productName: map['product_name'] as String?,
          productBarcode: map['product_barcode'] as String?,
        );
      }).toList();
    } catch (e) {
      log('Error searching batches: $e');
      return [];
    }
  }

  // إضافة دفعة جديدة
  Future<int> addBatch(Batch batch) async {
    try {
      final db = await _dbHelper.db;
      final id = await db.insert('product_batches', batch.toMap());

      // إعادة تحميل الدفعات
      await loadBatches(reset: true, filter: _currentFilter);

      log('✅ تم إضافة دفعة جديدة ID: $id');
      return id;
    } catch (e) {
      log('❌ خطأ في إضافة الدفعة: $e');
      rethrow;
    }
  }

  // تحديث دفعة
  Future<void> updateBatch(Batch batch) async {
    try {
      if (batch.id == null) throw Exception('لا يمكن تحديث دفعة بدون ID');

      final db = await _dbHelper.db;
      await db.update(
        'product_batches',
        batch.toMap(),
        where: 'id = ?',
        whereArgs: [batch.id],
      );

      // تحديث القائمة المحلية
      final index = _batches.indexWhere((b) => b.id == batch.id);
      if (index != -1) {
        _batches[index] = batch;
      }

      notifyListeners();
      log('✅ تم تحديث الدفعة ID: ${batch.id}');
    } catch (e) {
      log('❌ خطأ في تحديث الدفعة: $e');
      rethrow;
    }
  }

  // تفعيل/تعطيل دفعة
  Future<void> toggleBatchActive(int batchId, bool active) async {
    try {
      final db = await _dbHelper.db;
      await db.update(
        'product_batches',
        {'active': active ? 1 : 0},
        where: 'id = ?',
        whereArgs: [batchId],
      );

      // تحديث القائمة المحلية
      final index = _batches.indexWhere((b) => b.id == batchId);
      if (index != -1) {
        _batches[index].active = active;
      }

      notifyListeners();
      log('✅ تم ${active ? 'تفعيل' : 'تعطيل'} الدفعة ID: $batchId');
    } catch (e) {
      log('❌ خطأ في تغيير حالة الدفعة: $e');
      rethrow;
    }
  }

  // ========== الدوال الجديدة للتخلص والتحديث ==========

  // دالة لتحديث كمية المنتج عند التخلص من دفعة
  Future<void> _updateProductQuantity(
    int productId,
    double quantityToSubtract,
  ) async {
    try {
      if (quantityToSubtract <= 0) return;

      final db = await _dbHelper.db;

      // الحصول على الكمية الحالية للمنتج
      final productData = await db.query(
        'products',
        columns: ['id', 'quantity'],
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (productData.isEmpty) {
        log('⚠️ المنتج ID: $productId غير موجود');
        return;
      }

      final currentQuantity = (productData.first['quantity'] as num).toDouble();
      final newQuantity = currentQuantity - quantityToSubtract;

      // لا نسمح بالكمية السالبة
      final finalQuantity = newQuantity >= 0 ? newQuantity : 0;

      // تحديث كمية المنتج
      await db.update(
        'products',
        {'quantity': finalQuantity},
        where: 'id = ?',
        whereArgs: [productId],
      );

      log(
        '✅ تم تحديث كمية المنتج ID: $productId من $currentQuantity إلى $finalQuantity',
      );
    } catch (e) {
      log('❌ خطأ في تحديث كمية المنتج: $e');
      rethrow;
    }
  }

  // دالة للتخلص من جزء من الدفعة
  Future<void> disposeBatch(int batchId, double disposedQuantity) async {
    try {
      final db = await _dbHelper.db;

      // الحصول على الدفعة الحالية
      final batchData = await db.query(
        'product_batches',
        where: 'id = ?',
        whereArgs: [batchId],
      );

      if (batchData.isEmpty) {
        throw Exception('الدفعة غير موجودة');
      }

      final currentQuantity =
          (batchData.first['remaining_quantity'] as num).toDouble();
      final productId = batchData.first['product_id'] as int;
      final newQuantity = currentQuantity - disposedQuantity;

      if (newQuantity < 0) {
        throw Exception('الكمية المطلوبة أكبر من الكمية المتاحة');
      }

      // تحديث كمية الدفعة
      await db.update(
        'product_batches',
        {'remaining_quantity': newQuantity},
        where: 'id = ?',
        whereArgs: [batchId],
      );

      // إذا صارت الكمية 0، نعطل الدفعة تلقائياً
      if (newQuantity == 0) {
        await db.update(
          'product_batches',
          {'active': 0},
          where: 'id = ?',
          whereArgs: [batchId],
        );
      }

      // تحديث كمية المنتج (نطرح فقط الكمية التي تم التخلص منها)
      await _updateProductQuantity(productId, disposedQuantity);

      // تحديث القائمة المحلية
      final index = _batches.indexWhere((b) => b.id == batchId);
      if (index != -1) {
        _batches[index].remainingQuantity = newQuantity;
        if (newQuantity == 0) {
          _batches[index].active = false;
        }
      }

      notifyListeners();
      log('✅ تم التخلص من $disposedQuantity من الدفعة ID: $batchId');
    } catch (e) {
      log('❌ خطأ في التخلص من الدفعة: $e');
      rethrow;
    }
  }

  // دالة للحصول على دفعة معينة
  Future<Batch?> getBatchById(int batchId) async {
    try {
      final db = await _dbHelper.db;

      final result = await db.rawQuery(
        '''
        SELECT 
          pb.*,
          p.name as product_name,
          p.barcode as product_barcode,
          CASE 
            WHEN pb.expiry_date IS NULL THEN 9999
            ELSE julianday(pb.expiry_date) - julianday('now')
          END as days_remaining
        FROM product_batches pb
        LEFT JOIN products p ON pb.product_id = p.id
        WHERE pb.id = ?
      ''',
        [batchId],
      );

      if (result.isNotEmpty) {
        return Batch.fromMap(
          result.first,
          productName: result.first['product_name'] as String?,
          productBarcode: result.first['product_barcode'] as String?,
        );
      }
      return null;
    } catch (e) {
      log('Error getting batch by id: $e');
      return null;
    }
  }

  // دالة للتخلص الكامل من الدفعة (جعل الكمية 0)
  Future<void> disposeFullBatch(int batchId) async {
    try {
      final db = await _dbHelper.db;

      // الحصول على الدفعة الحالية
      final batchData = await db.query(
        'product_batches',
        where: 'id = ?',
        whereArgs: [batchId],
      );

      if (batchData.isEmpty) {
        throw Exception('الدفعة غير موجودة');
      }

      final currentQuantity =
          (batchData.first['remaining_quantity'] as num).toDouble();
      final productId = batchData.first['product_id'] as int;

      if (currentQuantity == 0) {
        throw Exception('الدفعة فارغة بالفعل');
      }

      // تحديث الكمية إلى 0 وتعطيل الدفعة
      await db.update(
        'product_batches',
        {'remaining_quantity': 0, 'active': 0},
        where: 'id = ?',
        whereArgs: [batchId],
      );

      // تحديث كمية المنتج (نطرح الكمية الكاملة)
      await _updateProductQuantity(productId, currentQuantity);

      // تحديث القائمة المحلية
      final index = _batches.indexWhere((b) => b.id == batchId);
      if (index != -1) {
        _batches[index].remainingQuantity = 0;
        _batches[index].active = false;
      }

      notifyListeners();
      log('✅ تم التخلص الكامل من الدفعة ID: $batchId');
    } catch (e) {
      log('❌ خطأ في التخلص الكامل من الدفعة: $e');
      rethrow;
    }
  }

  // حذف دفعة - تم التحديث لخصم كمية المنتج
  Future<void> deleteBatch(int batchId) async {
    try {
      final db = await _dbHelper.db;

      // الحصول على الدفعة قبل الحذف
      final batchData = await db.query(
        'product_batches',
        where: 'id = ?',
        whereArgs: [batchId],
      );

      if (batchData.isEmpty) {
        throw Exception('الدفعة غير موجودة');
      }

      final remainingQuantity =
          (batchData.first['remaining_quantity'] as num).toDouble();
      final productId = batchData.first['product_id'] as int;

      // 1. حذف الدفعة
      await db.delete('product_batches', where: 'id = ?', whereArgs: [batchId]);

      // 2. تحديث كمية المنتج (نطرح الكمية المتبقية في الدفعة)
      if (remainingQuantity > 0) {
        await _updateProductQuantity(productId, remainingQuantity);
      }

      // إزالة من القائمة المحلية
      _batches.removeWhere((b) => b.id == batchId);
      _totalBatches--;

      notifyListeners();
      log('✅ تم حذف الدفعة ID: $batchId');
    } catch (e) {
      log('❌ خطأ في حذف الدفعة: $e');
      rethrow;
    }
  }

  // ========== الدوال القديمة (تبقى كما هي) ==========

  // دالة للحصول على الدفعات المتاحة لمنتج
  Future<List<Map<String, dynamic>>> getProductBatches(int productId) async {
    try {
      final db = await _dbHelper.db;

      final batches = await db.query(
        'product_batches',
        where: 'product_id = ? AND remaining_quantity > 0 AND active = 1',
        whereArgs: [productId],
        orderBy: 'expiry_date ASC',
      );

      return batches;
    } catch (e) {
      print('خطأ في جلب الدفعات: $e');
      return [];
    }
  }

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
        'active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      // تحديث القائمة
      await loadBatches(reset: true, filter: _currentFilter);

      return batchId;
    } catch (e) {
      print('خطأ في إضافة الدفعة: $e');
      rethrow;
    }
  }

  // دالة لتحميل الدفعات حسب المنتج
  Future<List<Batch>> getBatchesByProduct(int productId) async {
    try {
      final db = await _dbHelper.db;

      final result = await db.rawQuery(
        '''
        SELECT 
          pb.*,
          p.name as product_name,
          p.barcode as product_barcode
        FROM product_batches pb
        LEFT JOIN products p ON pb.product_id = p.id
        WHERE pb.product_id = ? AND pb.remaining_quantity > 0
        ORDER BY pb.expiry_date ASC
      ''',
        [productId],
      );

      return result.map((map) {
        return Batch.fromMap(
          map,
          productName: map['product_name'] as String?,
          productBarcode: map['product_barcode'] as String?,
        );
      }).toList();
    } catch (e) {
      log('Error getting batches by product: $e');
      return [];
    }
  }

  // تحميل المنتجات للفلتر (إذا احتجتها في المستقبل)
  Future<void> loadProductsForFilter() async {
    // هذه الدالة غير مستخدمة حالياً بعد إزالة فلتر المنتج
    // يمكنك حذفها أو تركها للمستقبل
  }

  // دالة للحصول على كمية المنتج الحالية
  Future<double> getProductQuantity(int productId) async {
    try {
      final db = await _dbHelper.db;

      final productData = await db.query(
        'products',
        columns: ['quantity'],
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (productData.isEmpty) {
        throw Exception('المنتج غير موجود');
      }

      return (productData.first['quantity'] as num).toDouble();
    } catch (e) {
      log('Error getting product quantity: $e');
      return 0;
    }
  }
}
