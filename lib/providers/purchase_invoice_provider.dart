import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import 'dart:developer';

class PurchaseInvoiceProvider with ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> get invoices => _invoices;

  int _currentPage = 0;
  final int _itemsPerPage = 20;
  bool _hasMore = true;
  String _currentSearchQuery = '';
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _lastError;

  // Getters
  bool get hasMore => _hasMore;
  String get currentSearchQuery => _currentSearchQuery;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get hasError => _hasError;
  String? get lastError => _lastError;

  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> loadPurchaseInvoices({
    bool reset = false,
    String query = '',
    bool showLoading = true,
  }) async {
    if (_isLoading) return;

    // تحديث query الحالية
    _currentSearchQuery = query.trim();

    if (showLoading) {
      _isLoading = true;
      _hasError = false;
      _lastError = null;
      notifyListeners();
    }

    try {
      if (!_isInitialized) {
        await _checkDatabaseTables();
      }

      if (reset) {
        _currentPage = 0;
        _hasMore = true;
        _invoices.clear();
      }

      if (!_hasMore && !reset) {
        log('⏹️ لا يوجد المزيد من الفواتير للتحميل');
        return;
      }

      final db = await _dbHelper.db;

      String whereClause = '';
      List<dynamic> whereArgs = [];

      // بناء شرط البحث
      if (_currentSearchQuery.isNotEmpty) {
        // محاولة البحث برقم الفاتورة
        int? invoiceId = int.tryParse(_currentSearchQuery);

        if (invoiceId != null) {
          // البحث برقم الفاتورة
          whereClause = 'WHERE pi.id = ?';
          whereArgs = [invoiceId];
        } else {
          // البحث باسم المورد
          whereClause = 'WHERE s.name LIKE ?';
          whereArgs = ['%$_currentSearchQuery%']; // % للبحث الجزئي
        }
      } else {
        log('📄 تحميل جميع الفواتير');
      }

      final offset = _currentPage * _itemsPerPage;

      String sqlQuery = '''
        SELECT 
          pi.*, 
          s.name AS supplier_name
        FROM purchase_invoices pi
        LEFT JOIN suppliers s ON pi.supplier_id = s.id
        $whereClause
        ORDER BY pi.date DESC
        LIMIT $_itemsPerPage OFFSET $offset
      ''';

      final newInvoices = await db.rawQuery(sqlQuery, whereArgs);

      // تحويل البيانات لضمان أنواع صحيحة
      final convertedInvoices =
          newInvoices.map((invoice) {
            return {
              'id': _safeInt(invoice['id']),
              'supplier_id': _safeInt(invoice['supplier_id']),
              'supplier_name':
                  invoice['supplier_name']?.toString() ?? 'غير محدد',
              'date': invoice['date']?.toString() ?? '',
              'total_cost': _safeDouble(invoice['total_cost']),
              'paid_amount': _safeDouble(invoice['paid_amount']),
              'remaining_amount': _safeDouble(invoice['remaining_amount']),
              'payment_type': invoice['payment_type']?.toString() ?? 'cash',
              'note': invoice['note']?.toString() ?? '',
              'created_at': invoice['created_at']?.toString() ?? '',
              'updated_at': invoice['updated_at']?.toString() ?? '',
            };
          }).toList();

      if (reset) {
        _invoices = convertedInvoices;
      } else {
        _invoices.addAll(convertedInvoices);
      }

      // التحقق إذا كان هناك المزيد للتحميل
      _hasMore = convertedInvoices.length == _itemsPerPage;

      if (_hasMore) {
        _currentPage++;
      } else {
        log('⏹️ لا يوجد المزيد من الفواتير');
      }

      _isInitialized = true;
      _hasError = false;
      _lastError = null;
    } catch (e) {
      _hasError = true;
      _lastError = 'فشل في تحميل الفواتير: ${e.toString()}';

      // في حالة الخطأ، إعادة تعيين القائمة
      if (reset) {
        _invoices = [];
      }
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  // ============================================
  // دوال البحث والتحميل
  // ============================================

  // البحث في الفواتير
  Future<void> searchInvoices(String query) async {
    // إذا كان نفس البحث السابق والناتج ليس فارغاً، لا تفعل شيئاً
    if (query.trim() == _currentSearchQuery &&
        _invoices.isNotEmpty &&
        !_isLoading) {
      return;
    }

    await loadPurchaseInvoices(reset: true, query: query);
  }

  // تحميل المزيد من الفواتير
  Future<void> loadMoreInvoices() async {
    await loadPurchaseInvoices(reset: false, query: _currentSearchQuery);
  }

  // تحديث القائمة
  Future<void> refreshInvoices() async {
    await loadPurchaseInvoices(reset: true, query: _currentSearchQuery);
  }

  // إعادة تعيين البحث
  Future<void> resetSearch() async {
    _currentPage = 0;
    _hasMore = true;
    _invoices.clear();
    _currentSearchQuery = '';
    _hasError = false;
    _lastError = null;

    notifyListeners();

    // تحميل جميع الفواتير بعد الإعادة
    await loadPurchaseInvoices(reset: true, query: '');
  }

  // ============================================
  // دوال التحقق من قاعدة البيانات
  // ============================================
  Future<void> _checkDatabaseTables() async {
    try {
      final db = await _dbHelper.db;

      // تحقق من وجود جدول purchase_invoices
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='purchase_invoices'",
      );

      if (tables.isEmpty) {
        throw Exception('جدول purchase_invoices غير موجود في قاعدة البيانات');
      }

      // تحقق من وجود جدول suppliers
      final suppliersTable = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='suppliers'",
      );

      if (suppliersTable.isEmpty) {
        throw Exception('جدول suppliers غير موجود في قاعدة البيانات');
      }
    } catch (e) {
      _hasError = true;
      _lastError = e.toString();
      rethrow;
    }
  }

  // اختبار البحث مباشرة
  Future<void> testSearch(String query) async {
    try {
      final db = await _dbHelper.db;

      String whereClause = '';
      List<dynamic> whereArgs = [];

      if (query.isNotEmpty) {
        int? invoiceId = int.tryParse(query);
        if (invoiceId != null) {
          whereClause = 'WHERE pi.id = ?';
          whereArgs = [invoiceId];
        } else {
          whereClause = 'WHERE s.name LIKE ?';
          whereArgs = ['%$query%'];
        }
      }

      String sql = '''
        SELECT pi.id, s.name as supplier_name
        FROM purchase_invoices pi
        LEFT JOIN suppliers s ON pi.supplier_id = s.id
        $whereClause
        ORDER BY pi.date DESC
        LIMIT 10
      ''';

      final results = await db.rawQuery(sql, whereArgs);

      if (results.isNotEmpty) {
        for (var result in results) {
          log('  - ID: ${result['id']}, المورد: ${result['supplier_name']}');
        }
      } else {
        log('  لا توجد نتائج');
      }

      log('=== انتهى الاختبار ===\n');
    } catch (e) {
      log('❌ خطأ في اختبار البحث: $e');
    }
  }

  // ============================================
  // دوال CRUD الأساسية
  // ============================================
  Future<void> updatePurchaseInvoice({
    required int invoiceId,
    required String paymentType,
    required String note,
  }) async {
    try {
      final db = await _dbHelper.db;

      await db.update(
        'purchase_invoices',
        {
          'payment_type': paymentType,
          'note': note,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      log('✅ تم تحديث الفاتورة #$invoiceId');
      await refreshInvoices();
    } catch (e) {
      log('❌ خطأ في تحديث فاتورة الشراء: $e');
      rethrow;
    }
  }

  Future<int> addPurchaseInvoice({
    required int supplierId,
    required double totalCost,
    required String paymentType, // 'cash' أو 'credit' أو 'partial'
    double paidAmount = 0,
    String? note,
  }) async {
    try {
      final db = await _dbHelper.db;

      double remainingAmount = 0;

      // حساب المبالغ بناءً على طريقة الدفع
      if (paymentType == 'cash') {
        paidAmount = totalCost;
        remainingAmount = 0;
      } else if (paymentType == 'credit') {
        paidAmount = 0;
        remainingAmount = totalCost;
      } else if (paymentType == 'partial') {
        remainingAmount = totalCost - paidAmount;
      }

      // إدخال الفاتورة
      final invoiceId = await db.insert('purchase_invoices', {
        'supplier_id': supplierId,
        'date': DateTime.now().toIso8601String(),
        'total_cost': totalCost,
        'paid_amount': paidAmount,
        'remaining_amount': remainingAmount,
        'payment_type': paymentType,
        'note': note ?? '',
      });

      // 🔹 تسجيل حركة الشراء (دائماً)
      await db.insert('supplier_transactions', {
        'supplier_id': supplierId,
        'purchase_invoice_id': invoiceId,
        'amount': totalCost,
        'type': 'purchase',
        'date': DateTime.now().toIso8601String(),
        'note': 'فاتورة شراء #$invoiceId ($paymentType)',
      });

      // 🔹 تسجيل الدفعة (إذا وجدت)
      if (paidAmount > 0) {
        await db.insert('supplier_transactions', {
          'supplier_id': supplierId,
          'purchase_invoice_id': invoiceId,
          'amount': paidAmount,
          'type': 'payment',
          'date': DateTime.now().toIso8601String(),
          'note': 'دفعة على فاتورة #$invoiceId',
        });
        log('   ✅ تم تسجيل دفعة: $paidAmount');
      }

      // 🔹 تحديث رصيد المورد (فقط للدين المتبقي)
      if (remainingAmount > 0) {
        await db.rawInsert(
          '''
        INSERT INTO supplier_balance (supplier_id, balance, last_updated)
        VALUES (?, ?, ?)
        ON CONFLICT(supplier_id)
        DO UPDATE SET
          balance = balance + ?,
          last_updated = ?
        ''',
          [
            supplierId,
            remainingAmount,
            DateTime.now().toIso8601String(),
            remainingAmount,
            DateTime.now().toIso8601String(),
          ],
        );
      } else {
        log('   ✅ لا يوجد دين متبقي، لم يتم تحديث الرصيد');
      }

      await refreshInvoices();
      return invoiceId;
    } catch (e) {
      log('❌ خطأ في إضافة فاتورة الشراء: $e');
      rethrow;
    }
  }

  Future<double> getSupplierBalance(int supplierId) async {
    final db = await _dbHelper.db;

    final res = await db.query(
      'supplier_balance',
      columns: ['balance'],
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
    );

    if (res.isEmpty) return 0;
    return _safeDouble(res.first['balance']);
  }

  Future<void> deletePurchaseInvoice(int invoiceId) async {
    try {
      log('🗑️ جاري حذف الفاتورة #$invoiceId');
      final db = await _dbHelper.db;

      // أولاً: الحصول على معلومات الفاتورة
      final invoice = await db.query(
        'purchase_invoices',
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      if (invoice.isEmpty) {
        throw Exception('الفاتورة غير موجودة');
      }

      // ثانياً: حذف العناصر
      await db.delete(
        'purchase_items',
        where: 'purchase_id = ?',
        whereArgs: [invoiceId],
      );

      // ثالثاً: حذف الفاتورة
      await db.delete(
        'purchase_invoices',
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      log('✅ تم حذف الفاتورة #$invoiceId');

      // تحديث القائمة
      await refreshInvoices();
    } catch (e) {
      log('❌ خطأ في حذف فاتورة الشراء: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getInvoiceById(int invoiceId) async {
    try {
      final db = await _dbHelper.db;

      final result = await db.rawQuery(
        '''
        SELECT pi.*, s.name AS supplier_name
        FROM purchase_invoices pi
        LEFT JOIN suppliers s ON s.id = pi.supplier_id
        WHERE pi.id = ?
      ''',
        [invoiceId],
      );

      if (result.isEmpty) {
        throw Exception('الفاتورة غير موجودة');
      }

      final invoice = result.first;
      return {
        'id': _safeInt(invoice['id']),
        'supplier_id': _safeInt(invoice['supplier_id']),
        'supplier_name': invoice['supplier_name']?.toString() ?? 'غير محدد',
        'date': invoice['date']?.toString() ?? '',
        'total_cost': _safeDouble(invoice['total_cost']),
        'paid_amount': _safeDouble(invoice['paid_amount']),
        'remaining_amount': _safeDouble(invoice['remaining_amount']),
        'payment_type': invoice['payment_type']?.toString() ?? 'cash',
        'note': invoice['note']?.toString() ?? '',
        'created_at': invoice['created_at']?.toString() ?? '',
        'updated_at': invoice['updated_at']?.toString() ?? '',
      };
    } catch (e) {
      log('❌ خطأ في الحصول على الفاتورة: $e');
      rethrow;
    }
  }

  // دالة لفحص المشاكل في الاستعلام
  Future<void> diagnoseQuery(String query) async {
    try {
      log('\n🔧 === تشخيص استعلام البحث ===');
      log('البحث: "$query"');

      final db = await _dbHelper.db;

      // 1. فحص جداول قاعدة البيانات
      log('\n1. فحص الجداول:');
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      for (var table in tables) {
        log('   - ${table['name']}');
      }

      // 2. عدد السجلات في كل جدول
      log('\n2. عدد السجلات:');

      final purchaseCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM purchase_invoices',
      );
      log('   - purchase_invoices: ${_safeInt(purchaseCount.first['count'])}');

      final supplierCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM suppliers',
      );
      log('   - suppliers: ${_safeInt(supplierCount.first['count'])}');

      // 3. فحص بعض الموردين
      log('\n3. عينة من الموردين:');
      final suppliers = await db.rawQuery(
        'SELECT id, name FROM suppliers LIMIT 10',
      );
      for (var supplier in suppliers) {
        log('   - ID: ${supplier['id']}, Name: "${supplier['name']}"');
      }

      // 4. فحص بعض الفواتير مع الموردين
      log('\n4. فواتير مع معلومات الموردين:');
      final invoices = await db.rawQuery('''
        SELECT pi.id, pi.supplier_id, s.name as supplier_name
        FROM purchase_invoices pi
        LEFT JOIN suppliers s ON pi.supplier_id = s.id
        LIMIT 10
      ''');

      for (var invoice in invoices) {
        log(
          '   - Invoice ${invoice['id']}: Supplier "${invoice['supplier_name']}" (ID: ${invoice['supplier_id']})',
        );
      }

      // 5. اختبار البحث
      log('\n5. اختبار البحث:');

      if (query.isNotEmpty) {
        int? invoiceId = int.tryParse(query);

        if (invoiceId != null) {
          log('   البحث برقم فاتورة: $invoiceId');
          final results = await db.rawQuery(
            'SELECT id, supplier_id FROM purchase_invoices WHERE id = ?',
            [invoiceId],
          );
          log('   النتائج: ${results.length}');
        } else {
          log('   البحث باسم مورد: "$query"');
          final results = await db.rawQuery(
            'SELECT id, name FROM suppliers WHERE name LIKE ?',
            ['%$query%'],
          );
          log('   النتائج في جدول suppliers: ${results.length}');

          if (results.isNotEmpty) {
            for (var supplier in results) {
              final supplierId = _safeInt(supplier['id']);
              final invoicesForSupplier = await db.rawQuery(
                'SELECT COUNT(*) as count FROM purchase_invoices WHERE supplier_id = ?',
                [supplierId],
              );
              log(
                '   - المورد "${supplier['name']}" (ID: $supplierId) له ${_safeInt(invoicesForSupplier.first['count'])} فاتورة',
              );
            }
          }
        }
      }

      log('\n✅ === انتهى التشخيص ===\n');
    } catch (e, stackTrace) {
      log('\n❌ === خطأ في التشخيص ===');
      log('الخطأ: $e');
      log('Stack Trace: $stackTrace');
    }
  }

  // ============================================
  // بيانات فاتورة مؤقتة
  // ============================================

  int? _tempSelectedSupplierId;
  String? _tempPaymentType = 'cash';
  String? _tempNote;
  final List<Map<String, dynamic>> _tempInvoiceItems = [];
  double _tempInvoiceTotal = 0.0;
  double _tempDiscountValue = 0.0; // قيمة الخصم بالعملة

  // Getters
  int? get tempSelectedSupplierId => _tempSelectedSupplierId;
  String? get tempPaymentType => _tempPaymentType;
  String? get tempNote => _tempNote;
  List<Map<String, dynamic>> get tempInvoiceItems => _tempInvoiceItems;
  double get tempInvoiceTotal => _tempInvoiceTotal;
  double get tempDiscountValue => _tempDiscountValue;

  // حساب الإجمالي النهائي (بعد الخصم)
  double get tempInvoiceFinalTotal {
    double total = _tempInvoiceTotal;
    if (_tempDiscountValue > 0) {
      total = total - _tempDiscountValue;
      if (total < 0) total = 0;
    }
    return total;
  }

  // Setters
  void setTempSupplierId(int? id) {
    _tempSelectedSupplierId = id;
    notifyListeners();
  }

  void setTempPaymentType(String? type) {
    _tempPaymentType = type ?? 'cash';
    notifyListeners();
  }

  void setTempNote(String? note) {
    _tempNote = note;
    notifyListeners();
  }

  // دالة لتحديث قيمة الخصم
  void setTempDiscountValue(double discountValue) {
    // لا نسمح للخصم أن يكون أكبر من الإجمالي أو سالباً
    if (discountValue < 0) {
      _tempDiscountValue = 0.0;
    } else if (discountValue > _tempInvoiceTotal) {
      _tempDiscountValue = _tempInvoiceTotal;
    } else {
      _tempDiscountValue = discountValue;
    }
    notifyListeners();
  }

  void addTempItem(Map<String, dynamic> item) {
    _tempInvoiceItems.add(item);
    // تحديث الإجمالي
    double itemTotal =
        (item['quantity'] as num).toDouble() *
        (item['cost_price'] as num).toDouble();
    _tempInvoiceTotal += itemTotal;

    // تحديث الخصم إذا كان أكبر من الإجمالي الجديد
    if (_tempDiscountValue > _tempInvoiceTotal) {
      _tempDiscountValue = _tempInvoiceTotal;
    }
    notifyListeners();
  }

  void removeTempItem(int index) {
    if (index >= 0 && index < _tempInvoiceItems.length) {
      final removedItem = _tempInvoiceItems.removeAt(index);
      // تحديث الإجمالي
      double removedAmount =
          (removedItem['quantity'] as num).toDouble() *
          (removedItem['cost_price'] as num).toDouble();
      _tempInvoiceTotal -= removedAmount;

      // تحديث الخصم إذا كان أكبر من الإجمالي الجديد
      if (_tempDiscountValue > _tempInvoiceTotal) {
        _tempDiscountValue = _tempInvoiceTotal;
      }
      notifyListeners();
    }
  }

  void clearTempInvoice() {
    _tempSelectedSupplierId = null;
    _tempPaymentType = 'cash';
    _tempNote = null;
    _tempInvoiceItems.clear();
    _tempInvoiceTotal = 0.0;
    _tempDiscountValue = 0.0;
    notifyListeners();
  }

  // أضف هذه الدالة في PurchaseInvoiceProvider
  Future<void> updateInvoiceForReturn({
    required int invoiceId,
    required double returnAmount,
    required String note,
  }) async {
    try {
      final db = await _dbHelper.db;

      // جلب بيانات الفاتورة الحالية
      final currentInvoice = await getInvoiceById(invoiceId);

      double newTotalCost = currentInvoice['total_cost'] - returnAmount;
      double newRemainingAmount = currentInvoice['remaining_amount'];

      // تحديث المبلغ المتبقي
      if (newRemainingAmount > 0) {
        // إذا كان فيه دين، نقص من الدين
        newRemainingAmount = newRemainingAmount - returnAmount;
        if (newRemainingAmount < 0) newRemainingAmount = 0;
      }

      // تحديث الفاتورة
      await db.update(
        'purchase_invoices',
        {
          'total_cost': newTotalCost,
          'remaining_amount': newRemainingAmount,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      // تسجيل حركة الإرجاع
      await db.insert('supplier_transactions', {
        'supplier_id': currentInvoice['supplier_id'],
        'purchase_invoice_id': invoiceId,
        'amount': returnAmount,
        'type': 'return', // ✅ بعد ما تضيف return في CHECK constraint
        'date': DateTime.now().toIso8601String(),
        'note': note,
      });

      // تحديث رصيد المورد (نقص الرصيد)
      await db.rawInsert(
        '''
      INSERT INTO supplier_balance (supplier_id, balance, last_updated)
      VALUES (?, ?, ?)
      ON CONFLICT(supplier_id)
      DO UPDATE SET
        balance = balance - ?,
        last_updated = ?
      ''',
        [
          currentInvoice['supplier_id'],
          returnAmount,
          DateTime.now().toIso8601String(),
          returnAmount,
          DateTime.now().toIso8601String(),
        ],
      );

      log('✅ تم تحديث الفاتورة #$invoiceId للإرجاع بمبلغ: $returnAmount');

      // تحديث القائمة
      await refreshInvoices();
    } catch (e) {
      log('❌ خطأ في تحديث الفاتورة للإرجاع: $e');
      rethrow;
    }
  }

  // دالة لتسجيل الإرجاع بدون ربط بفاتورة (إرجاع مستقل)
  Future<void> addReturnTransaction({
    required int supplierId,
    required double returnAmount,
    required String note,
    int? purchaseInvoiceId, // اختياري: إذا كان الإرجاع مرتبط بفاتورة
  }) async {
    try {
      final db = await _dbHelper.db;

      // تسجيل حركة الإرجاع
      await db.insert('supplier_transactions', {
        'supplier_id': supplierId,
        'purchase_invoice_id': purchaseInvoiceId, // ممكن يكون null
        'amount': returnAmount,
        'type': 'return',
        'date': DateTime.now().toIso8601String(),
        'note': note,
      });

      // تحديث رصيد المورد (نقص الرصيد)
      await db.rawInsert(
        '''
      INSERT INTO supplier_balance (supplier_id, balance, last_updated)
      VALUES (?, ?, ?)
      ON CONFLICT(supplier_id)
      DO UPDATE SET
        balance = balance - ?,
        last_updated = ?
      ''',
        [
          supplierId,
          returnAmount,
          DateTime.now().toIso8601String(),
          returnAmount,
          DateTime.now().toIso8601String(),
        ],
      );

      // إذا كان الإرجاع مرتبط بفاتورة، نقوم بتحديث الفاتورة
      if (purchaseInvoiceId != null) {
        await updateInvoiceForReturn(
          invoiceId: purchaseInvoiceId,
          returnAmount: returnAmount,
          note: note,
        );
      }

      log('✅ تم تسجيل حركة إرجاع بقيمة: $returnAmount');

      // تحديث القائمة
      await refreshInvoices();
    } catch (e) {
      log('❌ خطأ في تسجيل حركة الإرجاع: $e');
      rethrow;
    }
  }

  // دالة للحصول على تفاصيل الفاتورة مع عناصرها
  Future<Map<String, dynamic>> getInvoiceDetails(int invoiceId) async {
    try {
      final db = await _dbHelper.db;

      // جلب الفاتورة
      final invoice = await getInvoiceById(invoiceId);

      // جلب عناصر الفاتورة
      final items = await db.rawQuery(
        '''
      SELECT 
        pi.*,
        p.name as product_name,
        p.barcode,
        pu.unit_name
      FROM purchase_items pi
      LEFT JOIN products p ON p.id = pi.product_id
      LEFT JOIN product_units pu ON pu.id = pi.unit_id
      WHERE pi.purchase_id = ?
    ''',
        [invoiceId],
      );

      // جلب معاملات الإرجاع للفاتورة
      final returns = await db.rawQuery(
        '''
      SELECT *
      FROM supplier_transactions
      WHERE purchase_invoice_id = ? AND type = 'return'
      ORDER BY date DESC
    ''',
        [invoiceId],
      );

      return {
        'invoice': invoice,
        'items': items,
        'returns': returns,
        'total_returned': returns.fold<double>(
          0.0,
          (sum, item) => sum + _safeDouble(item['amount']),
        ),
      };
    } catch (e) {
      log('❌ خطأ في جلب تفاصيل الفاتورة: $e');
      rethrow;
    }
  }
}
