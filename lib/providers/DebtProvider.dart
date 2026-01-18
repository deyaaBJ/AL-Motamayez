import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/customer_balance.dart';
import '../models/transaction.dart';
import 'dart:developer';

class DebtProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  // ==============================
  // بيانات محملة
  // ==============================
  CustomerBalance? _balance;
  List<Transaction> _transactions = [];

  CustomerBalance? get balance => _balance;
  List<Transaction> get transactions => _transactions;

  // ==============================
  // 1️⃣ تحميل رصيد الزبون من جدول customer_balance
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
  // 2️⃣ إضافة فاتورة آجلة (من جدول sales)
  // ==============================
  Future<void> addCreditSale({
    required int customerId,
    required double amount,
    String? note,
  }) async {
    final db = await _dbHelper.db;

    // تحديث الرصيد (يزيد الدين)
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
    notifyListeners();
  }

  // ==============================
  // 3️⃣ إضافة معاملة (دفعة أو صرف رصيد)
  // ==============================

  // ==============================
  // 3️⃣ إضافة معاملة (دفعة أو صرف رصيد) - المنطق الجديد
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
      'amount': amount, // سيتم التحويل تلقائياً إلى REAL في SQLite
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
    } else if (type == TransactionType.withdrawal) {
      // صرف رصيد: يزيد الرصيد (إذا كان سالباً) أو يقلل الدين (إذا كان موجباً)
      await db.rawUpdate(
        '''
      UPDATE customer_balance
      SET balance = balance - ?, last_updated = CURRENT_TIMESTAMP
      WHERE customer_id = ?
      ''',
        [amount, customerId],
      );
    }

    await loadCustomerBalance(customerId);
    await loadTransactionsPage(customerId);
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

  // دالة لصرف الرصيد
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
  // 4️⃣ تحميل المعاملات لزبون
  // ==============================
  Future<List<Transaction>> loadTransactionsPage(
    int customerId, {
    int page = 0,
    int limit = 20,
  }) async {
    final db = await _dbHelper.db;

    final offset = page * limit;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
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
  // 5️⃣ الحصول على إجمالي الدين من خلال customerId
  // ==============================
  Future<double> getTotalDebtByCustomerId(int customerId) async {
    try {
      final db = await _dbHelper.db;

      // 1. تحقق من وجود رصيد في customer_balance أولاً
      final balanceRes = await db.query(
        'customer_balance',
        where: 'customer_id = ?',
        whereArgs: [customerId],
        limit: 1,
      );

      if (balanceRes.isNotEmpty) {
        final balanceValue = balanceRes.first['balance'];
        final balance = _safeToDouble(balanceValue);
        log('Balance from customer_balance for customer $customerId: $balance');
        return balance;
      }

      // 2. إذا لم يكن هناك رصيد، احسب من الصفر
      return await calculateTotalDebtFromScratch(customerId);
    } catch (e) {
      log('Error calculating debt for customer $customerId: $e');
      return 0.0;
    }
  }

  // ==============================
  // 6️⃣ حساب إجمالي الدين من الصفر (من جدول sales و transactions)
  // ==============================
  Future<double> calculateTotalDebtFromScratch(int customerId) async {
    final db = await _dbHelper.db;

    try {
      log('Calculating debt from scratch for customer $customerId');

      // 1. مجموع الفواتير الآجلة من جدول sales
      double totalCreditSales = 0.0;
      try {
        final salesResult = await db.rawQuery(
          '''
        SELECT COALESCE(SUM(total_amount), 0) as total_credit
        FROM sales 
        WHERE customer_id = ? AND payment_type = 'credit'
        ''',
          [customerId],
        );

        // التحويل الآمن للقيمة
        final totalCreditValue = salesResult.first['total_credit'];
        totalCreditSales = _safeToDouble(totalCreditValue);

        log('Total credit sales from sales table: $totalCreditSales');
      } catch (e) {
        log('Error reading sales table: $e');
      }

      // 2. مجموع المعاملات من جدول transactions
      double totalPayments = 0.0;
      double totalWithdrawals = 0.0;

      try {
        // استخدم هذا الاستعلام بدلاً من السابق
        final transactionsResult = await db.rawQuery(
          '''
        SELECT 
          type,
          SUM(amount) as type_total
        FROM transactions 
        WHERE customer_id = ?
        GROUP BY type
        ''',
          [customerId],
        );

        for (var row in transactionsResult) {
          final type = row['type'] as String;
          final amountValue = row['type_total'];
          final amount = _safeToDouble(amountValue);

          if (type == 'payment') {
            totalPayments += amount;
          } else if (type == 'withdrawal') {
            totalWithdrawals += amount;
          }
        }

        log('Total payments: $totalPayments');
        log('Total withdrawals: $totalWithdrawals');
      } catch (e) {
        log('Error reading transactions table: $e');
      }

      // 3. الحساب النهائي
      // الدين = فواتير آجلة - دفعات - مسحوبات رصيد
      final totalDebt = totalCreditSales - totalPayments - totalWithdrawals;
      log('Calculated total debt: $totalDebt');

      return totalDebt;
    } catch (e) {
      log('Error calculating total debt from scratch: $e');
      return 0.0;
    }
  }

  // دالة مساعدة للتحويل الآمن إلى double
  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;

    if (value is double) {
      return value;
    } else if (value is int) {
      return value.toDouble();
    } else if (value is String) {
      // إزالة أي فاصلة عشرية وإحلالها بنقطة
      final cleanedValue = value.replaceAll(',', '.');
      return double.tryParse(cleanedValue) ?? 0.0;
    } else if (value is num) {
      return value.toDouble();
    }

    log(
      'Warning: Cannot convert value $value of type ${value.runtimeType} to double',
    );
    return 0.0;
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

      log('Recalculated balance for customer $customerId: $totalDebt');
    } catch (e) {
      log('Error recalculating balance: $e');
    }
  }

  // ==============================
  // 8️⃣ الحصول على إحصائيات مفصلة
  // ==============================
  Future<Map<String, dynamic>> getDebtStatistics(int customerId) async {
    final db = await _dbHelper.db;
    final Map<String, dynamic> stats = {};

    try {
      // 1. إجمالي الفواتير الآجلة
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

      stats['total_credit'] =
          creditSalesResult.first['total_credit'] as double? ?? 0.0;
      stats['credit_count'] =
          creditSalesResult.first['credit_count'] as int? ?? 0;

      // 2. إجمالي المعاملات
      final transactionsResult = await db.rawQuery(
        '''
        SELECT 
          COALESCE(SUM(CASE WHEN type = 'payment' THEN amount ELSE 0 END), 0) as total_payments,
          COALESCE(SUM(CASE WHEN type = 'withdrawal' THEN amount ELSE 0 END), 0) as total_withdrawals,
          COUNT(*) as transactions_count
        FROM transactions 
        WHERE customer_id = ?
        ''',
        [customerId],
      );

      stats['total_payments'] =
          transactionsResult.first['total_payments'] as double? ?? 0.0;
      stats['total_withdrawals'] =
          transactionsResult.first['total_withdrawals'] as double? ?? 0.0;
      stats['transactions_count'] =
          transactionsResult.first['transactions_count'] as int? ?? 0;

      // 3. الرصيد الحالي
      final currentBalance = await getTotalDebtByCustomerId(customerId);
      stats['current_balance'] = currentBalance;
    } catch (e) {
      log('Error getting debt statistics: $e');
    }

    return stats;
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
  // 🔟 دالة للفحص والتسجيل
  // ==============================
  Future<void> debugCustomerData(int customerId) async {
    final db = await _dbHelper.db;

    log('=== بدء فحص بيانات العميل $customerId ===');

    try {
      // 1. الفواتير الآجلة من جدول sales
      final sales = await db.rawQuery(
        'SELECT id, total_amount, created_at FROM sales WHERE customer_id = ? AND payment_type = "credit"',
        [customerId],
      );
      log('1. عدد الفواتير الآجلة: ${sales.length}');
      for (var sale in sales) {
        log(
          '   فاتورة ${sale['id']}: ${sale['total_amount']} (${sale['created_at']})',
        );
      }

      // 2. المعاملات من جدول transactions
      final transactions = await db.rawQuery(
        'SELECT id, amount, type, date, note FROM transactions WHERE customer_id = ? ORDER BY date DESC',
        [customerId],
      );
      log('2. عدد المعاملات: ${transactions.length}');
      for (var t in transactions) {
        log(
          '   معاملة ${t['id']}: ${t['amount']} (${t['type']}) في ${t['date']} - ${t['note']}',
        );
      }

      // 3. الرصيد من جدول customer_balance
      final balance = await db.query(
        'customer_balance',
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );
      log('3. سجلات customer_balance: ${balance.length}');
      if (balance.isNotEmpty) {
        log('   الرصيد: ${balance.first['balance']}');
        log('   آخر تحديث: ${balance.first['last_updated']}');
      }

      // 4. الحساب من الصفر
      final calculated = await calculateTotalDebtFromScratch(customerId);
      log('4. الرصيد المحسوب من الصفر: $calculated');
    } catch (e) {
      log('خطأ في الفحص: $e');
    }

    log('=== انتهاء الفحص ===');
  }

  // ==============================
  // 1️⃣1️⃣ تصحيح بيانات العميل
  // ==============================
  Future<void> fixCustomerData(int customerId) async {
    log('بدأ تصحيح بيانات العميل $customerId');

    // 1. أعد حساب الرصيد من الصفر
    await recalculateAndUpdateBalance(customerId);

    // 2. أعد تحميل البيانات
    await loadCustomerBalance(customerId);
    await loadTransactionsPage(customerId);

    log('تم تصحيح بيانات العميل $customerId');
  }

  // ==============================
  // 1️⃣2️⃣ تفريغ البيانات عند تغيير الزبون
  // ==============================
  void clear() {
    _balance = null;
    _transactions.clear();
    notifyListeners();
  }

  // ==============================
  // 1️⃣3️⃣ الحصول على الرصيد الحالي مباشرة
  // ==============================
  Future<double> getCurrentBalance(int customerId) async {
    try {
      return await getTotalDebtByCustomerId(customerId);
    } catch (e) {
      log('Error getting current balance: $e');
      return 0.0;
    }
  }
}
