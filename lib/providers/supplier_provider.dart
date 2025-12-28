import 'dart:async';
import 'package:flutter/material.dart';
import '../db/db_helper.dart';

class SupplierProvider with ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> get suppliers => _suppliers;

  int _currentPage = 0;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoading = false;
  String? _lastSearchQuery;
  final Map<int, double> _balanceCache = {};
  bool _isNotifying = false;

  // متغيرات جديدة للتحميل التفاعلي للحركات
  final Map<int, List<Map<String, dynamic>>> _transactionsCache = {};
  final Map<int, int> _transactionPage = {};
  final Map<int, bool> _hasMoreTransactions = {};
  final Map<int, bool> _isLoadingTransactions = {};
  final int _transactionsPageSize = 20;

  // دالة آمنة للإشعار
  void _safeNotifyListeners() {
    if (!_isNotifying) {
      _isNotifying = true;
      notifyListeners();
      _isNotifying = false;
    }
  }

  // استعلام محسن للبحث بالاسم فقط
  Future<void> loadSuppliers({
    bool loadMore = false,
    String? searchQuery,
  }) async {
    if (_isLoading) return;

    _isLoading = true;
    _safeNotifyListeners();

    try {
      final db = await _dbHelper.db;

      if (!loadMore) {
        _currentPage = 0;
        _hasMore = true;
        if (_lastSearchQuery != searchQuery) {
          _suppliers.clear();
        }
      }

      final offset = _currentPage * _pageSize;
      List<Map<String, dynamic>> results;

      if (searchQuery != null && searchQuery.isNotEmpty) {
        results = await db.rawQuery(
          '''
          SELECT 
            s.*,
            COALESCE(sb.balance, 0) as balance
          FROM suppliers s 
          LEFT JOIN supplier_balance sb ON s.id = sb.supplier_id 
          WHERE s.name LIKE ?
          ORDER BY s.name COLLATE NOCASE ASC
          LIMIT ? OFFSET ?
        ''',
          ['%$searchQuery%', _pageSize, offset],
        );

        _lastSearchQuery = searchQuery;
      } else {
        results = await db.rawQuery(
          '''
          SELECT 
            s.*,
            COALESCE(sb.balance, 0) as balance
          FROM suppliers s 
          LEFT JOIN supplier_balance sb ON s.id = sb.supplier_id 
          ORDER BY s.name COLLATE NOCASE ASC
          LIMIT ? OFFSET ?
        ''',
          [_pageSize, offset],
        );

        _lastSearchQuery = null;
      }

      // معالجة النتائج
      if (loadMore) {
        _suppliers.addAll(results);
      } else {
        _suppliers = results;
      }

      // تحديث الكاش
      for (var supplier in results) {
        if (supplier['id'] != null) {
          final balance =
              supplier['balance'] != null
                  ? (supplier['balance'] as num).toDouble()
                  : 0.0;
          _balanceCache[supplier['id'] as int] = balance;
        }
      }

      _currentPage++;
      _hasMore = results.length == _pageSize;
    } catch (e) {
      print('❌ خطأ في تحميل الموردين: $e');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<Map<String, dynamic>> getSupplierSummary(int supplierId) async {
    final db = await _dbHelper.db;

    try {
      final result = await db.rawQuery(
        '''
      SELECT 
        COUNT(*) as total_count,
        COALESCE(SUM(CASE WHEN type = 'invoice' THEN amount ELSE 0 END), 0) as total_invoices,
        COALESCE(SUM(CASE WHEN type = 'payment' THEN amount ELSE 0 END), 0) as total_payments,
        COALESCE(SUM(CASE 
          WHEN type = 'invoice' THEN amount 
          WHEN type = 'payment' THEN -amount 
          ELSE 0 
        END), 0) as net_balance,
        COALESCE(SUM(CASE 
          WHEN type = 'invoice' 
          AND EXISTS (
            SELECT 1 FROM purchase_invoices pi 
            WHERE pi.id = purchase_invoice_id AND pi.remaining_amount > 0
          ) 
          THEN amount ELSE 0 
        END), 0) as unpaid_invoices_total
      FROM supplier_transactions 
      WHERE supplier_id = ?
    ''',
        [supplierId],
      );

      if (result.isNotEmpty) {
        final row = result.first;
        final totalInvoices = (row['total_invoices'] as num?)?.toDouble() ?? 0;
        final totalPayments = (row['total_payments'] as num?)?.toDouble() ?? 0;
        final netBalance = (row['net_balance'] as num?)?.toDouble() ?? 0;
        final unpaidInvoices =
            (row['unpaid_invoices_total'] as num?)?.toDouble() ?? 0;

        // حساب النسب المئوية
        final paymentPercentage =
            totalInvoices > 0
                ? ((totalPayments / totalInvoices) * 100).clamp(0, 100)
                : 0;

        // تحديد الحالة بناءً على الرصيد
        String status;
        Color statusColor;
        bool isDebt = netBalance > 0;

        if (netBalance > 0) {
          status = 'مدين';
          statusColor = Colors.red;
        } else if (netBalance < 0) {
          status = 'دائن';
          statusColor = Colors.green;
        } else {
          status = 'متوازن';
          statusColor = Colors.blue;
        }

        return {
          'total_invoices': totalInvoices,
          'total_payments': totalPayments,
          'net_balance': netBalance,
          'total_count': row['total_count'] as int? ?? 0,
          'unpaid_invoices_total': unpaidInvoices,
          'payment_percentage': paymentPercentage,
          'balance_status': status,
          'status_color': statusColor,
          'is_debt': isDebt,
          'abs_balance': netBalance.abs(),
        };
      }

      return {
        'total_invoices': 0,
        'total_payments': 0,
        'net_balance': 0,
        'total_count': 0,
        'unpaid_invoices_total': 0,
        'payment_percentage': 0,
        'balance_status': 'متوازن',
        'status_color': Colors.blue,
        'is_debt': false,
        'abs_balance': 0,
      };
    } catch (e) {
      print('❌ خطأ في جلب ملخص الحركات: $e');
      return {
        'total_invoices': 0,
        'total_payments': 0,
        'net_balance': 0,
        'total_count': 0,
        'unpaid_invoices_total': 0,
        'payment_percentage': 0,
        'balance_status': 'متوازن',
        'status_color': Colors.blue,
        'is_debt': false,
        'abs_balance': 0,
      };
    }
  }

  Future<int> getSupplierTransactionsCount(
    int supplierId, {
    String? transactionType,
  }) async {
    final db = await _dbHelper.db;

    String typeCondition = '';
    List<dynamic> params = [supplierId];

    if (transactionType != null && transactionType != 'الكل') {
      if (transactionType == 'دفعات') {
        typeCondition = "AND type = ?";
        params.add('payment');
      } else if (transactionType == 'فواتير') {
        typeCondition = "AND type = ?";
        params.add('invoice');
      }
    }

    try {
      final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM supplier_transactions 
      WHERE supplier_id = ? $typeCondition
      ''', params);

      return result.isNotEmpty ? (result.first['count'] as int?) ?? 0 : 0;
    } catch (e) {
      print('❌ خطأ في جلب عدد الحركات: $e');
      return 0;
    }
  }

  // دالة محسنة لجلب الحركات مع lazy loading
  Future<List<Map<String, dynamic>>> getSupplierTransactions(
    int supplierId, {
    bool loadMore = false,
  }) async {
    if (_isLoadingTransactions[supplierId] == true) {
      return _transactionsCache[supplierId] ?? [];
    }

    _isLoadingTransactions[supplierId] = true;
    _safeNotifyListeners();

    try {
      final db = await _dbHelper.db;

      if (!loadMore) {
        _transactionPage[supplierId] = 0;
        _hasMoreTransactions[supplierId] = true;
        _transactionsCache[supplierId] = [];
      }

      final currentPage = _transactionPage[supplierId] ?? 0;
      final offset = currentPage * _transactionsPageSize;

      final results = await db.rawQuery(
        '''
        SELECT 
          st.*, 
          pi.id as invoice_id,
          pi.date as invoice_date,
          pi.total_cost,
          pi.paid_amount,
          pi.remaining_amount
        FROM supplier_transactions st
        LEFT JOIN purchase_invoices pi ON st.purchase_invoice_id = pi.id
        WHERE st.supplier_id = ?
        ORDER BY st.date DESC, st.created_at DESC, st.id DESC
        LIMIT ? OFFSET ?
        ''',
        [supplierId, _transactionsPageSize, offset],
      );

      if (loadMore) {
        final currentList = _transactionsCache[supplierId] ?? [];
        currentList.addAll(results);
        _transactionsCache[supplierId] = currentList;
      } else {
        _transactionsCache[supplierId] = List.from(results);
      }

      _transactionPage[supplierId] = currentPage + 1;
      _hasMoreTransactions[supplierId] =
          results.length == _transactionsPageSize;

      return results;
    } catch (e) {
      print('❌ خطأ في تحميل حركات المورد: $e');
      return [];
    } finally {
      _isLoadingTransactions[supplierId] = false;
      _safeNotifyListeners();
    }
  }

  // جلب عدد الحركات الكلي
  Future<int> getTotalTransactionsCount(int supplierId) async {
    final db = await _dbHelper.db;
    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM supplier_transactions WHERE supplier_id = ?',
        [supplierId],
      );
      return result.isNotEmpty ? (result.first['count'] as int?) ?? 0 : 0;
    } catch (e) {
      print('❌ خطأ في جلب عدد الحركات الكلي: $e');
      return 0;
    }
  }

  // البحث السريع - للاستخدام في الاقتراح التلقائي
  Future<List<Map<String, dynamic>>> quickSearch(
    String query, {
    int limit = 10,
  }) async {
    if (query.isEmpty) return [];

    final db = await _dbHelper.db;
    try {
      return await db.rawQuery(
        '''
        SELECT id, name, phone, address
        FROM suppliers 
        WHERE name LIKE ? 
        ORDER BY name COLLATE NOCASE ASC
        LIMIT ?
      ''',
        ['%$query%', limit],
      );
    } catch (e) {
      print('❌ خطأ في البحث السريع: $e');
      return [];
    }
  }

  // الحصول على رصيد المورد - مع الكاش
  Future<double> getSupplierBalance(int supplierId) async {
    if (_balanceCache.containsKey(supplierId)) {
      return _balanceCache[supplierId]!;
    }

    final db = await _dbHelper.db;
    try {
      final res = await db.rawQuery(
        '''
        SELECT balance FROM supplier_balance 
        WHERE supplier_id = ?
        LIMIT 1
      ''',
        [supplierId],
      );

      double balance = 0.0;
      if (res.isNotEmpty) {
        balance = (res.first['balance'] as num).toDouble();
      }
      _balanceCache[supplierId] = balance;
      return balance;
    } catch (e) {
      print('❌ خطأ في جلب رصيد المورد: $e');
      return 0.0;
    }
  }

  Future<Map<String, dynamic>> getSupplierBalanceDetails(int supplierId) async {
    final balance = await getSupplierBalance(supplierId);

    String status;
    Color statusColor;

    if (balance > 0) {
      status = 'أنت مدين للمورد بمبلغ ${balance.toStringAsFixed(2)}';
      statusColor = Colors.red;
    } else if (balance < 0) {
      status = 'المورد مدين لك بمبلغ ${(-balance).toStringAsFixed(2)}';
      statusColor = Colors.green;
    } else {
      status = 'لا يوجد دين';
      statusColor = Colors.blue;
    }

    return {
      'balance': balance,
      'status': status,
      'statusColor': statusColor,
      'abs_balance': balance.abs(),
    };
  }

  // إضافة مورد
  Future<void> addSupplier({
    required String name,
    String? phone,
    String? address,
    String? notes,
  }) async {
    final db = await _dbHelper.db;

    try {
      await db.transaction((txn) async {
        final supplierId = await txn.insert('suppliers', {
          'name': name,
          'phone': phone ?? '',
          'address': address ?? '',
          'notes': notes ?? '',
          'created_at': DateTime.now().toIso8601String(),
        });

        await txn.insert('supplier_balance', {
          'supplier_id': supplierId,
          'balance': 0.0,
          'last_updated': DateTime.now().toIso8601String(),
        });

        _balanceCache[supplierId] = 0.0;
      });

      await loadSuppliers(searchQuery: _lastSearchQuery);
    } catch (e) {
      print('❌ خطأ في إضافة المورد: $e');
      rethrow;
    }
  }

  // إضافة دفعة
  Future<void> addSupplierPayment({
    required int supplierId,
    int? purchaseInvoiceId,
    required double amount,
    String? note,
  }) async {
    final db = await _dbHelper.db;

    try {
      await db.transaction((txn) async {
        await txn.insert('supplier_transactions', {
          'supplier_id': supplierId,
          'purchase_invoice_id': purchaseInvoiceId,
          'amount': amount,
          'type': 'payment',
          'date': DateTime.now().toIso8601String(),
          'note':
              note ??
              (purchaseInvoiceId != null
                  ? 'دفعة على فاتورة #$purchaseInvoiceId'
                  : 'دفعة عامة'),
        });

        await txn.rawUpdate(
          '''
        UPDATE supplier_balance
        SET balance = balance - ?, last_updated = ?
        WHERE supplier_id = ?
        ''',
          [amount, DateTime.now().toIso8601String(), supplierId],
        );
      });

      final currentBalance = _balanceCache[supplierId] ?? 0;
      _balanceCache[supplierId] = currentBalance - amount;

      await loadSuppliers(searchQuery: _lastSearchQuery);
    } catch (e) {
      print('❌ خطأ في إضافة دفعة: $e');
      rethrow;
    }
  }

  // إحصائيات الموردين
  Future<Map<String, dynamic>> getSupplierStats(int supplierId) async {
    final db = await _dbHelper.db;

    try {
      final stats = await db.rawQuery(
        '''
        SELECT 
          COUNT(*) as total_invoices,
          SUM(total_cost) as total_purchases
        FROM purchase_invoices 
        WHERE supplier_id = ?
      ''',
        [supplierId],
      );

      final balance = await getSupplierBalance(supplierId);

      return {
        'total_invoices': (stats.first['total_invoices'] as int?) ?? 0,
        'total_purchases':
            (stats.first['total_purchases'] as num?)?.toDouble() ?? 0.0,
        'current_balance': balance,
      };
    } catch (e) {
      print('❌ خطأ في جلب إحصائيات المورد: $e');
      return {};
    }
  }

  // فواتير المورد للدروب داون
  Future<List<Map<String, dynamic>>> getSupplierInvoicesForDropdown(
    int supplierId,
  ) async {
    try {
      final db = await _dbHelper.db;

      final invoices = await db.rawQuery(
        '''
      SELECT 
        pi.id,
        pi.date,
        pi.total_cost,
        pi.paid_amount,
        pi.remaining_amount,
        pi.payment_type,
        pi.note,
        pi.created_at,
        strftime('%Y-%m-%d', pi.date) as formatted_date
      FROM purchase_invoices pi
      WHERE pi.supplier_id = ? 
        AND pi.remaining_amount > 0
        AND pi.total_cost > 0
      ORDER BY 
        CASE 
          WHEN pi.remaining_amount > (pi.total_cost * 0.5) THEN 1
          WHEN pi.remaining_amount > 0 THEN 2
          ELSE 3
        END,
        pi.date ASC
    ''',
        [supplierId],
      );

      final List<Map<String, dynamic>> result = [];

      for (var invoice in invoices) {
        try {
          final invoiceId = invoice['id'] as int;
          final totalCost = (invoice['total_cost'] as num).toDouble();
          final paidAmount = (invoice['paid_amount'] as num).toDouble();
          final remainingAmount =
              (invoice['remaining_amount'] as num).toDouble();

          result.add({
            'id': invoiceId,
            'total_cost': totalCost,
            'paid_amount': paidAmount,
            'remaining_amount': remainingAmount,
          });
        } catch (e) {
          print('خطأ في معالجة فاتورة: $e');
          continue;
        }
      }

      return result;
    } catch (e) {
      print('❌ خطأ في جلب فواتير المورد للدروب داون: $e');
      return [];
    }
  }

  // إعادة تعيين التحميل التفاعلي لمورد محدد
  void resetTransactionsPagination(int supplierId) {
    _transactionPage.remove(supplierId);
    _hasMoreTransactions.remove(supplierId);
    _transactionsCache.remove(supplierId);
    _isLoadingTransactions.remove(supplierId);
    _safeNotifyListeners();
  }

  // الحصول على الحركات المخبأة
  List<Map<String, dynamic>> getCachedTransactions(int supplierId) {
    return _transactionsCache[supplierId] ?? [];
  }

  // التحقق مما إذا كان هناك المزيد للتحميل
  bool hasMoreTransactions(int supplierId) {
    return _hasMoreTransactions[supplierId] ?? false;
  }

  // التحقق من حالة التحميل
  bool isLoadingTransactions(int supplierId) {
    return _isLoadingTransactions[supplierId] ?? false;
  }

  void resetPagination() {
    _currentPage = 0;
    _hasMore = true;
    _suppliers.clear();
    _safeNotifyListeners();
  }

  Future<void> loadMoreSuppliers() async {
    if (_hasMore && !_isLoading) {
      await loadSuppliers(loadMore: true, searchQuery: _lastSearchQuery);
    }
  }

  Future<void> searchSuppliers(String query) async {
    resetPagination();
    await loadSuppliers(searchQuery: query);
  }

  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
  String? get lastSearchQuery => _lastSearchQuery;
}
