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
    await loadPayments(customerId);
  }

  // ==============================
  // 4️⃣ تحميل الدفعات لزبون
  // ==============================
  Future<void> loadPayments(int customerId) async {
    final db = await _dbHelper.db;

    final res = await db.query(
      'payments',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'date DESC',
    );

    _payments = res.map((e) => Payment.fromMap(e)).toList();

    notifyListeners();
  }

  // ==============================
  // 5️⃣ إجمالي الدين (سريع جدًا)
  // ==============================
  double get totalDebt {
    return _balance?.balance ?? 0;
  }

  // ==============================
  // 6️⃣ تفريغ البيانات عند تغيير الزبون
  // ==============================
  void clear() {
    _balance = null;
    _payments = [];
    notifyListeners();
  }
}
