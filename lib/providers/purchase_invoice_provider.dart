// providers/purchase_invoice_provider.dart
import 'package:flutter/material.dart';
import '../db/db_helper.dart';

class PurchaseInvoiceProvider with ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> get invoices => _invoices;

  // متغيرات للتحميل التدريجي
  int _currentPage = 0;
  final int _itemsPerPage = 20;
  bool _hasMore = true;
  String _lastSearchQuery = '';

  // Getter للوصول للمتغيرات الخاصة
  bool get hasMore => _hasMore;
  String get lastSearchQuery => _lastSearchQuery;

  // === الدوال القديمة (لا تحذفها) ===

  // تحميل فواتير الشراء (بدون ترقيم الصفحات) - للحفاظ على التوافق
  Future<void> loadPurchaseInvoices() async {
    final db = await _dbHelper.db;

    _invoices = await db.rawQuery('''
      SELECT pi.*, s.name AS supplier_name
      FROM purchase_invoices pi
      JOIN suppliers s ON s.id = pi.supplier_id
      ORDER BY pi.date DESC
    ''');

    notifyListeners();
  }

  // إضافة فاتورة شراء جديدة
  Future<int> addPurchaseInvoice({
    required int supplierId,
    required double totalCost,
    required String paymentType,
    String? note,
  }) async {
    final db = await _dbHelper.db;

    final invoiceId = await db.insert('purchase_invoices', {
      'supplier_id': supplierId,
      'date': DateTime.now().toIso8601String(),
      'total_cost': totalCost,
      'payment_type': paymentType,
      'note': note ?? '',
    });

    await loadPurchaseInvoices();
    return invoiceId;
  }

  // حذف فاتورة شراء
  Future<void> deletePurchaseInvoice(int invoiceId) async {
    final db = await _dbHelper.db;

    // حذف العناصر أولاً
    await db.delete(
      'purchase_items',
      where: 'purchase_id = ?',
      whereArgs: [invoiceId],
    );

    // ثم حذف الفاتورة
    await db.delete(
      'purchase_invoices',
      where: 'id = ?',
      whereArgs: [invoiceId],
    );

    await loadPurchaseInvoices();
  }

  // تحديث الفاتورة
  Future<void> updatePurchaseInvoice({
    required int invoiceId,
    required String paymentType,
    String? note,
  }) async {
    final db = await _dbHelper.db;

    await db.update(
      'purchase_invoices',
      {'payment_type': paymentType, 'note': note ?? ''},
      where: 'id = ?',
      whereArgs: [invoiceId],
    );

    await loadPurchaseInvoices();
  }

  Future<void> updateInvoiceTotal({
    required int invoiceId,
    required double totalCost,
  }) async {
    final db = await _dbHelper.db;
    await db.update(
      'purchase_invoices',
      {'total_cost': totalCost},
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
    await loadPurchaseInvoices();
  }

  // === الدوال الجديدة للتحميل التدريجي ===

  // تحميل فواتير الشراء مع التحميل التدريجي
  Future<void> loadPurchaseInvoicesPaginated({
    bool reset = false,
    String query = '',
  }) async {
    if (reset) {
      _currentPage = 0;
      _hasMore = true;
      _invoices.clear();
      _lastSearchQuery = query;
    }

    if (!_hasMore && !reset) return;

    final db = await _dbHelper.db;

    // بناء استعلام البحث
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (query.isNotEmpty) {
      whereClause = '''
        WHERE (pi.id LIKE ? OR s.name LIKE ? OR pi.note LIKE ?)
      ''';
      whereArgs = ['%$query%', '%$query%', '%$query%'];
    }

    final offset = _currentPage * _itemsPerPage;

    final newInvoices = await db.rawQuery('''
      SELECT pi.*, s.name AS supplier_name
      FROM purchase_invoices pi
      JOIN suppliers s ON s.id = pi.supplier_id
      $whereClause
      ORDER BY pi.date DESC
      LIMIT $_itemsPerPage OFFSET $offset
    ''', whereArgs);

    if (reset) {
      _invoices = newInvoices;
    } else {
      _invoices.addAll(newInvoices);
    }

    // إذا كان عدد النتائج أقل من _itemsPerPage، فهذا يعني أنه لا يوجد المزيد
    _hasMore = newInvoices.length == _itemsPerPage;
    _currentPage++;

    notifyListeners();
  }

  // تحميل المزيد من الفواتير
  Future<void> loadMoreInvoices() async {
    await loadPurchaseInvoicesPaginated(reset: false, query: _lastSearchQuery);
  }

  // البحث في الفواتير
  Future<void> searchInvoices(String query) async {
    await loadPurchaseInvoicesPaginated(reset: true, query: query);
  }

  // تحديث القائمة
  Future<void> refreshInvoices() async {
    await loadPurchaseInvoicesPaginated(reset: true, query: _lastSearchQuery);
  }
}
