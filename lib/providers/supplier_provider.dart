import 'package:flutter/material.dart';
import '../db/db_helper.dart';

class SupplierProvider with ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> get suppliers => _suppliers;

  // تحميل كل الموردين
  Future<void> loadSuppliers() async {
    final db = await _dbHelper.db;
    _suppliers = await db.query('suppliers', orderBy: 'name ASC');
    notifyListeners();
  }

  // إضافة مورد
  // غير المعلمة من double? إلى int?
  Future<void> addSupplierPayment({
    required int supplierId,
    int? purchaseInvoiceId, // إذا كانت دفعة على فاتورة معينة
    required double amount,
    String? note,
  }) async {
    final db = await _dbHelper.db;

    // الحصول على الرصيد الحالي
    final currentBalance = await getSupplierBalance(supplierId);

    print('💰 جاري إضافة دفعة للمورد #$supplierId');
    print('   المبلغ: $amount');
    print('   الرصيد الحالي: $currentBalance');

    // تسجيل حركة الدفع
    await db.insert('supplier_transactions', {
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

    // تحديث رصيد المورد (خصم من الدين)
    // لأن الدفع يقلل من ديننا للمورد
    await db.rawUpdate(
      '''
    UPDATE supplier_balance
    SET balance = balance - ?, last_updated = ?
    WHERE supplier_id = ?
    ''',
      [amount, DateTime.now().toIso8601String(), supplierId],
    );

    final newBalance = currentBalance - amount;
    print('   ✅ تم تسجيل الدفعة');
    print('   الرصيد الجديد: $newBalance');

    if (newBalance > 0) {
      print('   ❗ لا يزال لديك دين للمورد: $newBalance');
    } else if (newBalance < 0) {
      print('   💚 المورد الآن مدين لك: ${-newBalance}');
    } else {
      print('   ✅ تم سداد جميع الديون');
    }

    notifyListeners();
  }

  // حذف مورد
  Future<void> deleteSupplier(int supplierId) async {
    final db = await _dbHelper.db;

    await db.delete('suppliers', where: 'id = ?', whereArgs: [supplierId]);

    await loadSuppliers();
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
    return (res.first['balance'] as num).toDouble();
  }

  Future<List<Map<String, dynamic>>> getSupplierTransactions(
    int supplierId,
  ) async {
    final db = await _dbHelper.db;

    return await db.query(
      'supplier_transactions',
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
      orderBy: 'date ASC',
    );
  }

  // في supplier_provider.dart
  // في supplier_provider.dart، تأكد من دالة addSupplier
  Future<void> addSupplier({
    required String name,
    String? phone,
    String? address,
    String? notes,
  }) async {
    final db = await _dbHelper.db;

    try {
      await db.insert('suppliers', {
        'name': name,
        'phone': phone ?? '',
        'address': address ?? '',
        'notes': notes ?? '',
        'created_at': DateTime.now().toIso8601String(),
      });

      await loadSuppliers();
      print('✅ تم إضافة المورد بنجاح');
    } catch (e) {
      print('❌ خطأ في إضافة المورد: $e');
      rethrow;
    }
  }

  // دالة محسنة لحساب رصيد المورد مع توضيح المعنى
  Future<Map<String, dynamic>> getSupplierBalanceDetails(int supplierId) async {
    final db = await _dbHelper.db;

    final result = await db.query(
      'supplier_balance',
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
    );

    double balance = 0.0;
    if (result.isNotEmpty) {
      balance = result.first['balance'] as double? ?? 0.0;
    }

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
}
