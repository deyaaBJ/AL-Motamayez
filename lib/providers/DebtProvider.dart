// في DebtProvider.dart
import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/customer_balance.dart';
import '../models/payments.dart';

class DebtProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  // ==============================
  // بيانات محملة
  // ==============================
  CustomerBalance? _balance;
  List<Payment> _payments = [];

  CustomerBalance? get balance => _balance;
  List<Payment> get payments => _payments;

  // ==============================
  // 1️⃣ تحميل رصيد الزبون
  // ==============================
  Future<void> loadCustomerBalance(int customerId) async {
    final db = await _dbHelper.db;

    final res = await db.query(
      'customer_balance',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      limit: 1,
    );

    if (res.isNotEmpty) {
      _balance = CustomerBalance.fromMap(res.first);
    } else {
      _balance = CustomerBalance(
        customerId: customerId,
        balance: 0,
        lastUpdated: DateTime.now(),
      );
    }

    notifyListeners();
  }

  // ==============================
  // 2️⃣ إضافة دين (فاتورة آجلة)
  // ==============================
  Future<void> addDebt({
    required int customerId,
    required double amount,
  }) async {
    final db = await _dbHelper.db;

    await db.rawInsert(
      '''
      INSERT INTO customer_balance (customer_id, balance, last_updated)
      VALUES (?, ?, CURRENT_TIMESTAMP)
      ON CONFLICT(customer_id)
      DO UPDATE SET
        balance = balance + ?,
        last_updated = CURRENT_TIMESTAMP
    ''',
      [customerId, amount, amount],
    );

    await loadCustomerBalance(customerId);
  }

  // ==============================
  // 3️⃣ تسجيل دفعة
  // ==============================
  Future<void> addPayment({
    required int customerId,
    required double amount,
    String? note,
  }) async {
    final db = await _dbHelper.db;

    // 1️⃣ أضف الدفعة
    await db.insert('payments', {
      'customer_id': customerId,
      'amount': amount,
      'date': DateTime.now().toIso8601String(),
      'note': note,
    });

    // 2️⃣ خصم من الدين
    await db.rawUpdate(
      '''
      UPDATE customer_balance
      SET balance = balance - ?, last_updated = CURRENT_TIMESTAMP
      WHERE customer_id = ?
    ''',
      [amount, customerId],
    );

    await loadCustomerBalance(customerId);
    await loadPaymentsPage(customerId);

    notifyListeners();
  }

  // ==============================
  // 4️⃣ تحميل الدفعات لزبون
  // ==============================
  Future<List<Payment>> loadPaymentsPage(
    int customerId, {
    int page = 0,
    int limit = 20,
  }) async {
    final db = await _dbHelper.db;

    final offset = page * limit;
    final List<Map<String, dynamic>> maps = await db.query(
      'payments',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'date DESC, id DESC',
      limit: limit,
      offset: offset,
    );

    return List.generate(maps.length, (i) => Payment.fromMap(maps[i]));
  }

  // ==============================
  // 5️⃣ إجمالي الدين (سريع جدًا) من الجدول المحدث
  // ==============================
  double get totalDebt {
    return _balance?.balance ?? 0;
  }

  // في DebtProvider.dart - أضف هذه الدالة
  Future<double> getTotalDebtByCustomerId(int customerId) async {
    final db = await _dbHelper.db;

    try {
      // 1. مجموع المبيعات الآجلة (credit)
      final salesResult = await db.rawQuery(
        '''
      SELECT COALESCE(SUM(total_amount), 0) as total_credit
      FROM sales 
      WHERE customer_id = ? AND payment_type = 'credit'
    ''',
        [customerId],
      );

      final totalCredit = salesResult.first['total_credit'] as double? ?? 0.0;

      // 2. مجموع الدفعات المدفوعة
      final paymentsResult = await db.rawQuery(
        '''
      SELECT COALESCE(SUM(amount), 0) as total_payments
      FROM payments 
      WHERE customer_id = ?
    ''',
        [customerId],
      );

      final totalPayments =
          paymentsResult.first['total_payments'] as double? ?? 0.0;

      // 3. الدين الإجمالي = مجموع المشتريات الآجلة - مجموع الدفعات
      return totalCredit - totalPayments;
    } catch (e) {
      print('Error calculating debt for customer $customerId: $e');
      return 0.0;
    }
  }

  // ==============================
  // 6️⃣ حساب إجمالي الدين من الصفر (مجموع الفواتير الآجلة ناقص الدفعات)
  // ==============================
  Future<double> calculateTotalDebtFromScratch(int customerId) async {
    final db = await _dbHelper.db;

    try {
      // 1. مجموع الفواتير الآجلة (المشتريات على الحساب)
      final salesResult = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(total_amount), 0) as total_credit
        FROM sales 
        WHERE customer_id = ? AND payment_type = 'credit'
      ''',
        [customerId],
      );

      final totalCredit = salesResult.first['total_credit'] as double? ?? 0.0;

      // 2. مجموع الدفعات المدفوعة
      final paymentsResult = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(amount), 0) as total_payments
        FROM payments 
        WHERE customer_id = ?
      ''',
        [customerId],
      );

      final totalPayments =
          paymentsResult.first['total_payments'] as double? ?? 0.0;

      // 3. الدين الإجمالي = مجموع المشتريات الآجلة - مجموع الدفعات
      return totalCredit - totalPayments;
    } catch (e) {
      print('Error calculating total debt from scratch: $e');
      return 0.0;
    }
  }

  // ==============================
  // 7️⃣ إعادة حساب وتحديث رصيد الزبون من الصفر
  // ==============================
  Future<void> recalculateAndUpdateBalance(int customerId) async {
    try {
      final totalDebt = await calculateTotalDebtFromScratch(customerId);
      final db = await _dbHelper.db;

      await db.rawInsert(
        '''
        INSERT OR REPLACE INTO customer_balance 
        (customer_id, balance, last_updated) 
        VALUES (?, ?, CURRENT_TIMESTAMP)
      ''',
        [customerId, totalDebt],
      );

      await loadCustomerBalance(customerId);
      notifyListeners();
    } catch (e) {
      print('Error recalculating balance: $e');
    }
  }

  // 9️⃣ الحصول على إحصائيات مفصلة للدين
  // ==============================
  Future<Map<String, dynamic>> getDebtStatistics(int customerId) async {
    final db = await _dbHelper.db;

    // 1. إجمالي المشتريات الآجلة
    final creditSalesResult = await db.rawQuery(
      '''
      SELECT 
        COALESCE(SUM(total_amount), 0) as total_credit,
        COUNT(*) as credit_count
      FROM sales 
      WHERE customer_id = ? AND payment_type = 'credit'
    ''',
      [customerId],
    );

    final totalCredit =
        creditSalesResult.first['total_credit'] as double? ?? 0.0;
    final creditCount = creditSalesResult.first['credit_count'] as int? ?? 0;

    // 2. إجمالي الدفعات
    final paymentsResult = await db.rawQuery(
      '''
      SELECT 
        COALESCE(SUM(amount), 0) as total_payments,
        COUNT(*) as payments_count,
        MIN(date) as first_payment,
        MAX(date) as last_payment
      FROM payments 
      WHERE customer_id = ?
    ''',
      [customerId],
    );

    final totalPayments =
        paymentsResult.first['total_payments'] as double? ?? 0.0;
    final paymentsCount = paymentsResult.first['payments_count'] as int? ?? 0;
    final firstPayment = paymentsResult.first['first_payment'] as String?;
    final lastPayment = paymentsResult.first['last_payment'] as String?;

    // 3. الدين الحالي
    final currentDebt = totalCredit - totalPayments;

    return {
      'total_credit': totalCredit,
      'credit_count': creditCount,
      'total_payments': totalPayments,
      'payments_count': paymentsCount,
      'current_debt': currentDebt,
      'first_payment': firstPayment,
      'last_payment': lastPayment,
      'average_credit': creditCount > 0 ? totalCredit / creditCount : 0.0,
      'average_payment':
          paymentsCount > 0 ? totalPayments / paymentsCount : 0.0,
    };
  }

  // ==============================
  // 🔟 تفريغ البيانات عند تغيير الزبون
  // ==============================
  void clear() {
    _balance = null;
    _payments = [];
    notifyListeners();
  }
}
