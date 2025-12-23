// providers/purchase_invoice_provider.dart

import 'package:flutter/material.dart';
import '../db/db_helper.dart';

class PurchaseInvoiceProvider with ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> get invoices => _invoices;

  // تحميل فواتير الشراء
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

    await loadPurchaseInvoices(); // تحديث القائمة
    return invoiceId;
  }

  // تحديث مجموع الفاتورة
  Future<void> updatePurchaseInvoiceTotal(int invoiceId, double total) async {
    final db = await _dbHelper.db;

    await db.update(
      'purchase_invoices',
      {'total_cost': total},
      where: 'id = ?',
      whereArgs: [invoiceId],
    );

    await loadPurchaseInvoices();
  }

  // حذف فاتورة شراء (مع حذف العناصر أولاً)
  Future<void> deletePurchaseInvoice(int invoiceId) async {
    final db = await _dbHelper.db;

    // حذف العناصر أولاً (للحفاظ على سلامة البيانات)
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

    await loadPurchaseInvoices(); // تحديث القائمة
  }
}
