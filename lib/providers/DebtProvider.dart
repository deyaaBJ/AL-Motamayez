// في DebtProvider.dart
import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/customer_balance.dart';
import '../models/transaction.dart'; // تم تغييرها من payments.dart

class DebtProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  // ==============================
  // بيانات محملة
  // ==============================
  CustomerBalance? _balance;
  List<Transaction> _transactions = []; // تم تغييرها من List<Payment>

  CustomerBalance? get balance => _balance;
  List<Transaction> get transactions => _transactions;

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
  // 3️⃣ إضافة معاملة (الآن تدعم نوعين)
  // ==============================
  Future<void> addTransaction({
    required int customerId,
    required double amount,
    String? note,
    required TransactionType type,
  }) async {
    final db = await _dbHelper.db;

    // 1️⃣ أضف المعاملة في جدول transactions
    await db.insert('transactions', {
      'customer_id': customerId,
      'amount': amount,
      'type': type.name,
      'date': DateTime.now().toIso8601String(),
      'note': note,
    });

    // 2️⃣ عدل الرصيد بناءً على نوع المعاملة
    if (type == TransactionType.payment) {
      // تسديد دفعة: يخصم من الرصيد (يقلل الدين)
      await db.rawUpdate(
        '''
        UPDATE customer_balance
        SET balance = balance - ?, last_updated = CURRENT_TIMESTAMP
        WHERE customer_id = ?
        ''',
        [amount, customerId],
      );
    } else {
      // صرف رصيد: يضيف للرصيد (يزيد الرصيد المتاح أو يقلل الدين)
      await db.rawUpdate(
        '''
        UPDATE customer_balance
        SET balance = balance + ?, last_updated = CURRENT_TIMESTAMP
        WHERE customer_id = ?
        ''',
        [amount, customerId],
      );
    }

    await loadCustomerBalance(customerId);
    await loadTransactionsPage(customerId); // تم تغيير اسم الدالة
    notifyListeners();
  }

  // دالة مساعدة للتوافق مع الكود القديم (تسديد دفعة)
  Future<void> addPayment({
    required int customerId,
    required double amount,
    String? note,
  }) async {
    return addTransaction(
      customerId: customerId,
      amount: amount,
      note: note,
      type: TransactionType.payment,
    );
  }

  // دالة جديدة لصرف الرصيد
  Future<void> addWithdrawal({
    required int customerId,
    required double amount,
    String? note,
  }) async {
    return addTransaction(
      customerId: customerId,
      amount: amount,
      note: note,
      type: TransactionType.withdrawal,
    );
  }

  // ==============================
  // 4️⃣ تحميل المعاملات لزبون (دفعات + صرف رصيد)
  // ==============================
  Future<List<Transaction>> loadTransactionsPage(
    int customerId, {
    int page = 0,
    int limit = 20,
  }) async {
    final db = await _dbHelper.db;

    final offset = page * limit;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions', // تم تغيير اسم الجدول من payments
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'date DESC, id DESC',
      limit: limit,
      offset: offset,
    );

    _transactions = List.generate(
      maps.length,
      (i) => Transaction.fromMap(maps[i]),
    );
    notifyListeners();

    return _transactions;
  }

  // ==============================
  // 5️⃣ إجمالي الدين (سريع جدًا) من الجدول المحدث
  // ==============================
  double get totalDebt {
    return _balance?.balance ?? 0;
  }

  // دالة للحصول على إجمالي الدين من خلال customerId
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

      // 2. مجموع المعاملات: الدفعات تخصم، وصرف الرصيد يضيف
      final transactionsResult = await db.rawQuery(
        '''
        SELECT 
          COALESCE(SUM(CASE WHEN type = 'payment' THEN amount ELSE 0 END), 0) as total_payments,
          COALESCE(SUM(CASE WHEN type = 'withdrawal' THEN amount ELSE 0 END), 0) as total_withdrawals
        FROM transactions 
        WHERE customer_id = ?
        ''',
        [customerId],
      );

      final totalPayments =
          transactionsResult.first['total_payments'] as double? ?? 0.0;
      final totalWithdrawals =
          transactionsResult.first['total_withdrawals'] as double? ?? 0.0;

      // 3. الدين الإجمالي = مجموع المشتريات الآجلة - مجموع الدفعات + مجموع صرف الرصيد
      return totalCredit - totalPayments + totalWithdrawals;
    } catch (e) {
      print('Error calculating debt for customer $customerId: $e');
      return 0.0;
    }
  }

  // ==============================
  // 6️⃣ حساب إجمالي الدين من الصفر (مجموع الفواتير الآجلة ناقص الدفعات + صرف الرصيد)
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

      // 2. مجموع المعاملات
      final transactionsResult = await db.rawQuery(
        '''
        SELECT 
          COALESCE(SUM(CASE WHEN type = 'payment' THEN amount ELSE 0 END), 0) as total_payments,
          COALESCE(SUM(CASE WHEN type = 'withdrawal' THEN amount ELSE 0 END), 0) as total_withdrawals
        FROM transactions 
        WHERE customer_id = ?
        ''',
        [customerId],
      );

      final totalPayments =
          transactionsResult.first['total_payments'] as double? ?? 0.0;
      final totalWithdrawals =
          transactionsResult.first['total_withdrawals'] as double? ?? 0.0;

      // 3. الدين الإجمالي = مجموع المشتريات الآجلة - مجموع الدفعات + مجموع صرف الرصيد
      return totalCredit - totalPayments + totalWithdrawals;
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

  // ==============================
  // 8️⃣ الحصول على إحصائيات مفصلة للدين
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

    // 2. إجمالي المعاملات
    final transactionsResult = await db.rawQuery(
      '''
      SELECT 
        COALESCE(SUM(CASE WHEN type = 'payment' THEN amount ELSE 0 END), 0) as total_payments,
        COALESCE(SUM(CASE WHEN type = 'withdrawal' THEN amount ELSE 0 END), 0) as total_withdrawals,
        COUNT(*) as transactions_count,
        MIN(date) as first_transaction,
        MAX(date) as last_transaction
      FROM transactions 
      WHERE customer_id = ?
      ''',
      [customerId],
    );

    final totalPayments =
        transactionsResult.first['total_payments'] as double? ?? 0.0;
    final totalWithdrawals =
        transactionsResult.first['total_withdrawals'] as double? ?? 0.0;
    final transactionsCount =
        transactionsResult.first['transactions_count'] as int? ?? 0;
    final firstTransaction =
        transactionsResult.first['first_transaction'] as String?;
    final lastTransaction =
        transactionsResult.first['last_transaction'] as String?;

    // 3. الدين الحالي
    final currentDebt = totalCredit - totalPayments + totalWithdrawals;

    return {
      'total_credit': totalCredit,
      'credit_count': creditCount,
      'total_payments': totalPayments,
      'total_withdrawals': totalWithdrawals,
      'transactions_count': transactionsCount,
      'current_debt': currentDebt,
      'first_transaction': firstTransaction,
      'last_transaction': lastTransaction,
      'average_credit': creditCount > 0 ? totalCredit / creditCount : 0.0,
      'average_transaction':
          transactionsCount > 0
              ? (totalPayments + totalWithdrawals) / transactionsCount
              : 0.0,
    };
  }

  // ==============================
  // 9️⃣ تصفية المعاملات حسب النوع
  // ==============================
  List<Transaction> getPaymentsOnly() {
    return _transactions
        .where((t) => t.type == TransactionType.payment)
        .toList();
  }

  List<Transaction> getWithdrawalsOnly() {
    return _transactions
        .where((t) => t.type == TransactionType.withdrawal)
        .toList();
  }

  // ==============================
  // 🔟 تفريغ البيانات عند تغيير الزبون
  // ==============================
  void clear() {
    _balance = null;
    _transactions.clear();
    notifyListeners();
  }
}
