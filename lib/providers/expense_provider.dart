import 'package:flutter/material.dart';
import 'package:motamayez/db/db_helper.dart';
import 'package:motamayez/models/expense.dart';

class ExpenseProvider with ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  List<Expense> _expenses = [];
  List<Expense> _filteredExpenses = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 0;
  final int _limit = 20;

  // متغيرات الفلتر
  String? _currentFilterType;
  DateTime? _currentFilterFrom;
  DateTime? _currentFilterTo;
  String? _currentPaymentType;
  String? _currentSearchQuery;

  List<Expense> get expenses => _filteredExpenses;
  List<Expense> get allExpenses => _expenses;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get currentFilterType => _currentFilterType;

  double get totalExpenses {
    return _expenses.fold(0, (sum, e) => sum + e.amount);
  }

  // تحميل المصاريف مع Pagination ودعم الفلترات
  Future<void> fetchExpenses({bool loadMore = false}) async {
    if (!loadMore) {
      _page = 0;
      _expenses.clear();
      _filteredExpenses.clear();
      _hasMore = true;
    }

    if (!_hasMore && loadMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      final db = await _dbHelper.db;

      // بناء استعلام SQL ديناميكي مع الفلترات
      String where = '';
      List<Object?> whereArgs = [];

      // فلتر النوع
      if (_currentFilterType != null && _currentFilterType!.isNotEmpty) {
        where = 'type = ?';
        whereArgs.add(_currentFilterType);
      }

      // فلتر التاريخ
      if (_currentFilterFrom != null || _currentFilterTo != null) {
        if (_currentFilterFrom != null) {
          final fromStr = _formatDateForDb(_currentFilterFrom!);
          if (where.isNotEmpty) where += ' AND ';
          where += "substr(date, 1, 10) >= ?";
          whereArgs.add(fromStr);
        }
        if (_currentFilterTo != null) {
          final toStr = _formatDateForDb(_currentFilterTo!);
          if (where.isNotEmpty) where += ' AND ';
          where += "substr(date, 1, 10) <= ?";
          whereArgs.add(toStr);
        }
      }

      // فلتر طريقة الدفع
      if (_currentPaymentType != null && _currentPaymentType!.isNotEmpty) {
        if (where.isNotEmpty) where += ' AND ';
        where += 'paymentType = ?';
        whereArgs.add(_currentPaymentType);
      }

      // فلتر البحث
      if (_currentSearchQuery != null && _currentSearchQuery!.isNotEmpty) {
        if (where.isNotEmpty) where += ' AND ';
        where += '(type LIKE ? OR note LIKE ?)';
        String searchPattern = '%${_currentSearchQuery}%';
        whereArgs.add(searchPattern);
        whereArgs.add(searchPattern);
      }

      // جلب البيانات مع pagination
      final result = await db.query(
        'expenses',
        where: where.isEmpty ? null : where,
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'date DESC, id DESC',
        limit: _limit,
        offset: _page * _limit,
      );

      final newExpenses = result.map((e) => Expense.fromMap(e)).toList();

      if (loadMore) {
        _expenses.addAll(newExpenses);
        _filteredExpenses.addAll(newExpenses);
      } else {
        _expenses = newExpenses;
        _filteredExpenses = newExpenses;
      }

      _hasMore = newExpenses.length == _limit;
      _page++;
    } catch (error) {
      debugPrint('Error fetching expenses: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // تحميل المزيد
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    await fetchExpenses(loadMore: true);
  }

  // فلترة حسب التاريخ مع pagination
  Future<void> filterByDate({DateTime? from, DateTime? to}) async {
    _currentFilterType = null;
    _currentPaymentType = null;
    _currentSearchQuery = null;
    _currentFilterFrom = from;
    _currentFilterTo = to;
    await fetchExpenses();
  }

  // فلترة حسب النوع مع pagination
  Future<void> filterByType(String type) async {
    _currentFilterType = type;
    _currentPaymentType = null;
    _currentSearchQuery = null;
    _currentFilterFrom = null;
    _currentFilterTo = null;
    _page = 0;
    _hasMore = true;
    await fetchExpenses();
  }

  // فلترة حسب طريقة الدفع مع pagination
  Future<void> filterByPaymentType(String paymentType) async {
    _currentPaymentType = paymentType;
    _currentFilterType = null;
    _currentSearchQuery = null;
    _currentFilterFrom = null;
    _currentFilterTo = null;
    _page = 0;
    _hasMore = true;
    await fetchExpenses();
  }

  // فلترة بالبحث مع pagination
  Future<void> filterBySearch(String query) async {
    _currentSearchQuery = query;
    _currentFilterType = null;
    _currentPaymentType = null;
    _currentFilterFrom = null;
    _currentFilterTo = null;
    _page = 0;
    _hasMore = true;
    await fetchExpenses();
  }

  // إعادة تعيين الفلتر
  Future<void> resetFilter() async {
    _currentFilterType = null;
    _currentPaymentType = null;
    _currentSearchQuery = null;
    _currentFilterFrom = null;
    _currentFilterTo = null;
    await fetchExpenses();
  }

  // إضافة مصروف
  Future<void> addExpense(Expense expense) async {
    try {
      final db = await _dbHelper.db;
      await db.insert('expenses', expense.toMap());

      // إعادة تحميل البيانات مع الفلترات الحالية
      await fetchExpenses();
    } catch (error) {
      debugPrint('Error adding expense: $error');
      rethrow;
    }
  }

  // تحديث مصروف
  Future<void> updateExpense(Expense expense) async {
    try {
      final db = await _dbHelper.db;
      await db.update(
        'expenses',
        expense.toMap(),
        where: 'id = ?',
        whereArgs: [expense.id],
      );

      // إعادة تحميل البيانات مع الفلترات الحالية
      await fetchExpenses();
    } catch (error) {
      debugPrint('Error updating expense: $error');
      rethrow;
    }
  }

  // حذف مصروف
  Future<void> deleteExpense(int id) async {
    try {
      final db = await _dbHelper.db;
      await db.delete('expenses', where: 'id = ?', whereArgs: [id]);

      // إعادة تحميل البيانات مع الفلترات الحالية
      await fetchExpenses();
    } catch (error) {
      debugPrint('Error deleting expense: $error');
      rethrow;
    }
  }

  // إحصائيات
  double getTodayTotal() {
    final today = DateTime.now();
    final todayStr = _formatDateForDb(today);

    return _expenses
        .where((e) {
          try {
            final expenseDate = e.date.split('T')[0];
            return expenseDate == todayStr;
          } catch (e) {
            return false;
          }
        })
        .fold(0, (sum, e) => sum + e.amount);
  }

  double getMonthlyTotal() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    return _expenses
        .where((e) {
          try {
            final expenseDate = DateTime.parse(e.date);
            return expenseDate.year == year && expenseDate.month == month;
          } catch (e) {
            return false;
          }
        })
        .fold(0, (sum, e) => sum + e.amount);
  }

  // دالة مساعدة لتحويل التاريخ
  String _formatDateForDb(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
  }

  // الحصول على أنواع المصاريف الفريدة
  List<String> getUniqueTypes() {
    return _expenses.map((e) => e.type).toSet().toList();
  }

  // الحصول على طرق الدفع الفريدة
  List<String> getUniquePaymentTypes() {
    return _expenses
        .where((e) => e.paymentType != null)
        .map((e) => e.paymentType!)
        .toSet()
        .toList();
  }

  // الحصول على حالة الفلتر الحالي (للعرض في UI)
  Map<String, dynamic> getFilterState() {
    return {
      'type': _currentFilterType,
      'from': _currentFilterFrom,
      'to': _currentFilterTo,
      'paymentType': _currentPaymentType,
      'searchQuery': _currentSearchQuery,
    };
  }
}
