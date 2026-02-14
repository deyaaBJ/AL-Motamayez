// reports_provider.dart - النسخة الكاملة المعدلة
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';
import 'dart:developer';

class ReportsProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ المتغيرات والإحصائيات ██████████████████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████

  // حالة التحميل
  bool _isLoadingReports = false;
  bool get isLoadingReports => _isLoadingReports;

  // الإحصائيات الأساسية للمبيعات
  double _totalSalesAmount = 0;
  double _totalProfit = 0;
  int _salesCount = 0;
  double _profitPercentage = 0;
  double _cashSalesAmount = 0;
  double _creditSalesAmount = 0;
  int _totalCustomers = 0; // تمت الإضافة
  String? _bestSalesDay;

  // مصاريف ومقاييس الربحية
  double _totalCashProfit = 0; // الأرباح النقدية فقط
  double _totalExpensesAll = 0; // كل المصاريف
  double _totalCashExpenses = 0; // المصاريف النقدية فقط
  double _netCashProfit = 0; // صافي الربح النقدي
  double _adjustedNetProfit = 0; // صافي الربح المعدل
  double _netProfit = 0; // صافي الربح الأساسي

  // قوائم المنتجات والعملاء
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _topCustomers = [];
  List<Map<String, dynamic>> _weeklySalesData = [];

  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ Getters ████████████████████████████████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████

  double get totalSalesAmount => _totalSalesAmount;
  double get totalProfit => _totalProfit;
  int get salesCount => _salesCount;
  double get profitPercentage => _profitPercentage;
  double get cashSalesAmount => _cashSalesAmount;
  double get creditSalesAmount => _creditSalesAmount;
  int get totalCustomers => _totalCustomers; // تمت الإضافة
  String? get bestSalesDay => _bestSalesDay;
  double get totalCashProfit => _totalCashProfit;
  double get totalExpensesAll => _totalExpensesAll;
  double get totalCashExpenses => _totalCashExpenses;
  double get netCashProfit => _netCashProfit;
  double get adjustedNetProfit => _adjustedNetProfit;
  double get netProfit => _netProfit;
  List<Map<String, dynamic>> get topProducts => _topProducts;
  List<Map<String, dynamic>> get topCustomers => _topCustomers;
  List<Map<String, dynamic>> get weeklySalesData => _weeklySalesData;

  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ دوال التحميل الرئيسية ██████████████████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████

  Future<void> loadReportsData() async {
    _isLoadingReports = true;
    notifyListeners();

    try {
      await Future.wait([
        _loadTopProducts(),
        _loadTopCustomers(),
        _loadWeeklySalesData(),
      ]);

      // تحميل البيانات للفترة الافتراضية (آخر 30 يوم)
      await _filterSales('default');
    } catch (e) {
      log('Error loading reports data: $e');
    }

    _isLoadingReports = false;
    notifyListeners();
  }

  Future<void> filterByPeriod(String period) async {
    _isLoadingReports = true;
    notifyListeners();

    try {
      await _filterSales(period);
    } catch (e) {
      log('Error filtering reports: $e');
    }

    _isLoadingReports = false;
    notifyListeners();
  }

  Future<void> filterBySpecificMonth(int month, int year) async {
    _isLoadingReports = true;
    notifyListeners();

    try {
      await _filterSales('specific-month', month: month, year: year);
    } catch (e) {
      log('Error in filterBySpecificMonth: $e');
    }

    _isLoadingReports = false;
    notifyListeners();
  }

  Future<void> filterBySpecificYear(int year) async {
    _isLoadingReports = true;
    notifyListeners();

    try {
      await _filterSales('specific-year', year: year);
    } catch (e) {
      log('Error in filterBySpecificYear: $e');
    }

    _isLoadingReports = false;
    notifyListeners();
  }

  Future<void> filterByCustomDate(DateTime fromDate, DateTime toDate) async {
    _isLoadingReports = true;
    notifyListeners();

    try {
      final fromStr = _formatDateForSQL(fromDate);
      final toStr = _formatDateForSQL(toDate);

      await _filterSalesByCustomDate(fromDate: fromStr, toDate: toStr);
    } catch (e) {
      log('Error in filterByCustomDate: $e');
    }

    _isLoadingReports = false;
    notifyListeners();
  }

  // دالة applyDateFilterToReports المطلوبة - تمت الإضافة
  Future<void> applyDateFilterToReports({
    required String fromDate,
    required String toDate,
  }) async {
    _isLoadingReports = true;
    notifyListeners();

    try {
      await _filterSalesByCustomDate(fromDate: fromDate, toDate: toDate);
    } catch (e) {
      log('Error in applyDateFilterToReports: $e');
    }

    _isLoadingReports = false;
    notifyListeners();
  }

  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ الدالة الرئيسية للفلترة ████████████████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████

  Future<void> _filterSales(String period, {int? month, int? year}) async {
    try {
      String whereClause = '';
      List<dynamic> whereArgs = [];
      final now = DateTime.now();

      switch (period) {
        case 'اليوم':
          whereClause = "date(date) = date(?)";
          whereArgs = [now.toIso8601String()];
          break;
        case 'الأسبوع':
          final weekAgo = now.subtract(Duration(days: 7));
          whereClause = "date(date) >= date(?)";
          whereArgs = [weekAgo.toIso8601String()];
          break;
        case 'الشهر':
          whereClause = "strftime('%Y-%m', date) = ?";
          whereArgs = [DateFormat('yyyy-MM').format(now)];
          break;
        case 'السنة':
          whereClause = "strftime('%Y', date) = ?";
          whereArgs = [now.year.toString()];
          break;
        case 'specific-month':
          whereClause = "strftime('%Y-%m', date) = ?";
          String formattedMonth = month!.toString().padLeft(2, '0');
          whereArgs = ['$year-$formattedMonth'];
          break;
        case 'specific-year':
          whereClause = "strftime('%Y', date) = ?";
          whereArgs = [year.toString()];
          break;
        case 'default':
          whereClause = "date(date) >= date('now', '-30 days')";
          whereArgs = [];
          break;
        default:
          whereClause = "date(date) >= date('now', '-30 days')";
          whereArgs = [];
      }

      // 1. جلب المبيعات المصفاة
      final filteredSales = await _getFilteredSales(whereClause, whereArgs);

      // 2. حساب إحصائيات المبيعات
      _calculateSalesStats(filteredSales);

      // 3. حساب المصاريف مع نفس الفلتر
      await _calculateExpensesWithFilter(whereClause, whereArgs);

      // 4. حساب جميع مقاييس الربحية
      _calculateAllProfitMetrics();

      // 5. تحميل أفضل المنتجات والعملاء
      await _loadFilteredTopProducts(whereClause, whereArgs);
      await _loadFilteredTopCustomers(whereClause, whereArgs);

      // 6. التحقق من الحسابات
      _debugCalculations();
    } catch (e) {
      log('Error in _filterSales: $e');
      rethrow;
    }
  }

  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ دوال الدعم الرئيسية ████████████████████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████

  Future<List<Map<String, dynamic>>> _getFilteredSales(
    String whereClause,
    List<dynamic> whereArgs,
  ) async {
    final db = await _dbHelper.db;

    try {
      // محاولة استعلام مع sales_archive
      return await db.rawQuery(
        '''
        SELECT * FROM sales
        WHERE $whereClause
        UNION ALL
        SELECT * FROM sales_archive
        WHERE $whereClause
        ORDER BY date DESC
      ''',
        [...whereArgs, ...whereArgs],
      );
    } catch (e) {
      // إذا فشل الاستعلام (مثل عدم وجود جدول sales_archive)
      // جرب الاستعلام من جدول sales فقط
      log('Warning: sales_archive error, falling back to sales table only: $e');
      return await db.rawQuery('''
        SELECT * FROM sales
        WHERE $whereClause
        ORDER BY date DESC
      ''', whereArgs);
    }
  }

  void _calculateSalesStats(List<Map<String, dynamic>> sales) {
    _salesCount = sales.length;
    _totalSalesAmount = 0;
    _totalProfit = 0;
    _cashSalesAmount = 0;
    _creditSalesAmount = 0;
    _totalCashProfit = 0;

    Map<String, double> dailySales = {};
    Set<dynamic> uniqueCustomers = {}; // تتبع العملاء الفريدين

    for (var sale in sales) {
      final amount = (sale['total_amount'] as num?)?.toDouble() ?? 0;
      final profit = (sale['total_profit'] as num?)?.toDouble() ?? 0;
      final paymentType = sale['payment_type'] as String?;
      final dateStr = (sale['date'] as String?)?.split(' ')[0];
      final customerId = sale['customer_id'];

      _totalSalesAmount += amount;
      _totalProfit += profit;

      if (paymentType == 'cash') {
        _cashSalesAmount += amount;
        _totalCashProfit += profit;
      } else if (paymentType == 'credit') {
        _creditSalesAmount += amount;
      }

      // تسجيل العملاء الفريدين فقط
      if (customerId != null) {
        uniqueCustomers.add(customerId);
      }

      if (dateStr != null) {
        dailySales[dateStr] = (dailySales[dateStr] ?? 0) + amount;
      }
    }

    // عد العملاء الفريدين فقط
    _totalCustomers = uniqueCustomers.length;

    _profitPercentage =
        _totalSalesAmount > 0 ? (_totalProfit / _totalSalesAmount) * 100 : 0;

    _calculateBestSalesDay(dailySales);
  }

  void _calculateBestSalesDay(Map<String, double> dailySales) {
    if (dailySales.isEmpty) {
      _bestSalesDay = 'لا يوجد بيانات';
      return;
    }

    final bestDayEntry = dailySales.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );

    try {
      final date = DateTime.parse(bestDayEntry.key);
      final days = [
        'الأحد',
        'الاثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
        'السبت',
      ];
      _bestSalesDay = days[date.weekday % 7];
    } catch (e) {
      _bestSalesDay = 'غير معروف';
    }
  }

  Future<void> _calculateExpensesWithFilter(
    String whereClause,
    List<dynamic> whereArgs,
  ) async {
    try {
      final db = await _dbHelper.db;

      final totalExpensesResult = await db.rawQuery('''
        SELECT SUM(amount) as total_expenses_all
        FROM expenses
        WHERE $whereClause
      ''', whereArgs);

      _totalExpensesAll =
          (totalExpensesResult.first['total_expenses_all'] as num?)
              ?.toDouble() ??
          0;

      final cashExpensesResult = await db.rawQuery('''
        SELECT SUM(amount) as total_cash_expenses
        FROM expenses
        WHERE $whereClause AND payment_type = 'نقدي'
      ''', whereArgs);

      _totalCashExpenses =
          (cashExpensesResult.first['total_cash_expenses'] as num?)
              ?.toDouble() ??
          0;
    } catch (e) {
      log('Error in _calculateExpensesWithFilter: $e');
      _totalExpensesAll = 0;
      _totalCashExpenses = 0;
    }
  }

  void _calculateAllProfitMetrics() {
    _netProfit = _totalProfit - _totalExpensesAll;
    _netCashProfit = _totalCashProfit - _totalCashExpenses;
    _adjustedNetProfit = _netProfit;
  }

  Future<void> _loadFilteredTopProducts(
    String whereClause,
    List<dynamic> whereArgs,
  ) async {
    try {
      final db = await _dbHelper.db;

      // تعديل whereClause لتحديد اسم الجدول بشكل صريح (s.date بدلاً من date)
      String adjustedWhereClause = whereClause
          .replaceAll('date(date)', 'date(s.date)')
          .replaceAll("strftime('%Y-%m', date)", "strftime('%Y-%m', s.date)")
          .replaceAll("strftime('%Y', date)", "strftime('%Y', s.date)");

      final result = await db.rawQuery('''
        SELECT 
          p.name,
          p.base_unit,
          SUM(
            CASE 
              WHEN si.unit_type = 'piece' THEN si.quantity
              WHEN si.unit_type = 'kg' THEN si.quantity
              WHEN si.unit_type = 'custom' AND pu.contain_qty IS NOT NULL THEN si.quantity * pu.contain_qty
              ELSE si.quantity
            END
          ) as total_quantity,
          COUNT(DISTINCT si.sale_id) as sale_count,
          SUM(si.subtotal) as total_revenue,
          SUM(si.profit) as total_profit
        FROM sale_items si
        JOIN products p ON si.product_id = p.id
        JOIN sales s ON si.sale_id = s.id
        LEFT JOIN product_units pu ON si.unit_id = pu.id
        WHERE $adjustedWhereClause
        GROUP BY p.id, p.name, p.base_unit
        ORDER BY total_revenue DESC
        LIMIT 10
      ''', whereArgs);

      _topProducts =
          result.map((row) {
            return {
              'name': row['name'] as String? ?? 'غير معروف',
              'quantity': (row['total_quantity'] as num?)?.toDouble() ?? 0,
              'sale_count': row['sale_count'] as int? ?? 0,
              'revenue': (row['total_revenue'] as num?)?.toDouble() ?? 0,
              'profit': (row['total_profit'] as num?)?.toDouble() ?? 0,
              'unit': _getDisplayUnit(row['base_unit'] as String?),
            };
          }).toList();
    } catch (e) {
      log('Error in _loadFilteredTopProducts: $e');
      _topProducts = [];
    }
  }

  Future<void> _loadFilteredTopCustomers(
    String whereClause,
    List<dynamic> whereArgs,
  ) async {
    try {
      final db = await _dbHelper.db;

      // تعديل whereClause لتحديد اسم الجدول بشكل صريح (s.date بدلاً من date)
      String adjustedWhereClause = whereClause
          .replaceAll('date(date)', 'date(s.date)')
          .replaceAll("strftime('%Y-%m', date)", "strftime('%Y-%m', s.date)")
          .replaceAll("strftime('%Y', date)", "strftime('%Y', s.date)");

      final result = await db.rawQuery('''
        SELECT 
          c.name,
          COUNT(s.id) as purchase_count,
          SUM(s.total_amount) as total_amount,
          SUM(s.total_profit) as total_profit
        FROM sales s
        LEFT JOIN customers c ON s.customer_id = c.id
        WHERE $adjustedWhereClause AND c.id IS NOT NULL
        GROUP BY c.id, c.name
        HAVING total_amount > 0
        ORDER BY total_amount DESC
        LIMIT 10
      ''', whereArgs);

      _topCustomers =
          result.map((row) {
            return {
              'name': row['name'] as String? ?? 'عميل نقدي',
              'purchase_count': row['purchase_count'] as int? ?? 0,
              'total_amount': (row['total_amount'] as num?)?.toDouble() ?? 0,
              'total_profit': (row['total_profit'] as num?)?.toDouble() ?? 0,
            };
          }).toList();
    } catch (e) {
      log('Error in _loadFilteredTopCustomers: $e');
      _topCustomers = [];
    }
  }

  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ فلترة التاريخ المخصص ███████████████████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████

  Future<void> _filterSalesByCustomDate({
    required String fromDate,
    required String toDate,
  }) async {
    try {
      final db = await _dbHelper.db;

      List<Map<String, dynamic>> sales;
      try {
        // محاولة الاستعلام مع sales_archive
        sales = await db.rawQuery(
          '''
          SELECT * FROM sales
          WHERE date(date) BETWEEN ? AND ?
          UNION ALL
          SELECT * FROM sales_archive
          WHERE date(date) BETWEEN ? AND ?
          ORDER BY date DESC
        ''',
          [fromDate, toDate, fromDate, toDate],
        );
      } catch (e) {
        // إذا فشل الاستعلام، استخدم جدول sales فقط
        log('Warning: sales_archive error in custom date filter: $e');
        sales = await db.rawQuery(
          '''
          SELECT * FROM sales
          WHERE date(date) BETWEEN ? AND ?
          ORDER BY date DESC
        ''',
          [fromDate, toDate],
        );
      }

      _calculateSalesStats(sales);

      await _calculateExpensesForCustomDate(fromDate, toDate);

      _calculateAllProfitMetrics();

      await _loadTopProductsForCustomDate(fromDate, toDate);
      await _loadTopCustomersForCustomDate(fromDate, toDate);

      _debugCalculations();
    } catch (e) {
      log('Error in _filterSalesByCustomDate: $e');
      rethrow;
    }
  }

  Future<void> _calculateExpensesForCustomDate(
    String fromDate,
    String toDate,
  ) async {
    try {
      final db = await _dbHelper.db;

      final totalExpensesResult = await db.rawQuery(
        '''
        SELECT SUM(amount) as total_expenses_all
        FROM expenses
        WHERE date(date) BETWEEN ? AND ?
      ''',
        [fromDate, toDate],
      );

      _totalExpensesAll =
          (totalExpensesResult.first['total_expenses_all'] as num?)
              ?.toDouble() ??
          0;

      final cashExpensesResult = await db.rawQuery(
        '''
        SELECT SUM(amount) as total_cash_expenses
        FROM expenses
        WHERE date(date) BETWEEN ? AND ? AND payment_type = 'نقدي'
      ''',
        [fromDate, toDate],
      );

      _totalCashExpenses =
          (cashExpensesResult.first['total_cash_expenses'] as num?)
              ?.toDouble() ??
          0;
    } catch (e) {
      log('Error in _calculateExpensesForCustomDate: $e');
      _totalExpensesAll = 0;
      _totalCashExpenses = 0;
    }
  }

  Future<void> _loadTopProductsForCustomDate(
    String fromDate,
    String toDate,
  ) async {
    try {
      final db = await _dbHelper.db;

      final result = await db.rawQuery(
        '''
        SELECT 
          p.name,
          p.base_unit,
          SUM(
            CASE 
              WHEN si.unit_type = 'piece' THEN si.quantity
              WHEN si.unit_type = 'kg' THEN si.quantity
              WHEN si.unit_type = 'custom' AND pu.contain_qty IS NOT NULL THEN si.quantity * pu.contain_qty
              ELSE si.quantity
            END
          ) as total_quantity,
          COUNT(DISTINCT si.sale_id) as sale_count,
          SUM(si.subtotal) as total_revenue,
          SUM(si.profit) as total_profit
        FROM sale_items si
        JOIN products p ON si.product_id = p.id
        JOIN sales s ON si.sale_id = s.id
        LEFT JOIN product_units pu ON si.unit_id = pu.id
        WHERE date(s.date) BETWEEN ? AND ?
        GROUP BY p.id, p.name, p.base_unit
        ORDER BY total_revenue DESC
        LIMIT 10
      ''',
        [fromDate, toDate],
      );

      _topProducts =
          result.map((row) {
            return {
              'name': row['name'] as String? ?? 'غير معروف',
              'quantity': (row['total_quantity'] as num?)?.toDouble() ?? 0,
              'sale_count': row['sale_count'] as int? ?? 0,
              'revenue': (row['total_revenue'] as num?)?.toDouble() ?? 0,
              'profit': (row['total_profit'] as num?)?.toDouble() ?? 0,
              'unit': _getDisplayUnit(row['base_unit'] as String?),
            };
          }).toList();
    } catch (e) {
      log('Error in _loadTopProductsForCustomDate: $e');
      _topProducts = [];
    }
  }

  Future<void> _loadTopCustomersForCustomDate(
    String fromDate,
    String toDate,
  ) async {
    try {
      final db = await _dbHelper.db;

      final result = await db.rawQuery(
        '''
        SELECT 
          c.name,
          COUNT(s.id) as purchase_count,
          SUM(s.total_amount) as total_amount,
          SUM(s.total_profit) as total_profit
        FROM sales s
        LEFT JOIN customers c ON s.customer_id = c.id
        WHERE date(s.date) BETWEEN ? AND ? AND c.id IS NOT NULL
        GROUP BY c.id, c.name
        HAVING total_amount > 0
        ORDER BY total_amount DESC
        LIMIT 10
      ''',
        [fromDate, toDate],
      );

      _topCustomers =
          result.map((row) {
            return {
              'name': row['name'] as String? ?? 'عميل نقدي',
              'purchase_count': row['purchase_count'] as int? ?? 0,
              'total_amount': (row['total_amount'] as num?)?.toDouble() ?? 0,
              'total_profit': (row['total_profit'] as num?)?.toDouble() ?? 0,
            };
          }).toList();
    } catch (e) {
      log('Error in _loadTopCustomersForCustomDate: $e');
      _topCustomers = [];
    }
  }

  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ دوال التحميل المساعدة ██████████████████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████

  Future<void> _loadTopProducts() async {
    try {
      final db = await _dbHelper.db;

      final result = await db.rawQuery('''
        SELECT 
          p.name,
          p.base_unit,
          SUM(
            CASE 
              WHEN si.unit_type = 'piece' THEN si.quantity
              WHEN si.unit_type = 'kg' THEN si.quantity
              WHEN si.unit_type = 'custom' AND pu.contain_qty IS NOT NULL THEN si.quantity * pu.contain_qty
              ELSE si.quantity
            END
          ) as total_quantity,
          COUNT(DISTINCT si.sale_id) as sale_count,
          SUM(si.subtotal) as total_revenue,
          SUM(si.profit) as total_profit
        FROM sale_items si
        JOIN products p ON si.product_id = p.id
        JOIN sales s ON si.sale_id = s.id
        LEFT JOIN product_units pu ON si.unit_id = pu.id
        WHERE s.date >= date('now', '-30 days')
        GROUP BY p.id, p.name, p.base_unit
        ORDER BY total_revenue DESC
        LIMIT 10
      ''');

      _topProducts =
          result.map((row) {
            return {
              'name': row['name'] as String? ?? 'غير معروف',
              'quantity': (row['total_quantity'] as num?)?.toDouble() ?? 0,
              'sale_count': row['sale_count'] as int? ?? 0,
              'revenue': (row['total_revenue'] as num?)?.toDouble() ?? 0,
              'profit': (row['total_profit'] as num?)?.toDouble() ?? 0,
              'unit': _getDisplayUnit(row['base_unit'] as String?),
            };
          }).toList();
    } catch (e) {
      log('Error in _loadTopProducts: $e');
      _topProducts = [];
    }
  }

  Future<void> _loadTopCustomers() async {
    try {
      final db = await _dbHelper.db;

      final result = await db.rawQuery('''
        SELECT 
          c.name,
          COUNT(s.id) as purchase_count,
          SUM(s.total_amount) as total_amount,
          SUM(s.total_profit) as total_profit
        FROM sales s
        LEFT JOIN customers c ON s.customer_id = c.id
        WHERE s.date >= date('now', '-30 days') AND c.id IS NOT NULL
        GROUP BY c.id, c.name
        HAVING total_amount > 0
        ORDER BY total_amount DESC
        LIMIT 10
      ''');

      _topCustomers =
          result.map((row) {
            return {
              'name': row['name'] as String? ?? 'عميل نقدي',
              'purchase_count': row['purchase_count'] as int? ?? 0,
              'total_amount': (row['total_amount'] as num?)?.toDouble() ?? 0,
              'total_profit': (row['total_profit'] as num?)?.toDouble() ?? 0,
            };
          }).toList();
    } catch (e) {
      log('Error in _loadTopCustomers: $e');
      _topCustomers = [];
    }
  }

  Future<void> _loadWeeklySalesData() async {
    try {
      final db = await _dbHelper.db;

      List<Map<String, dynamic>> result;
      try {
        // محاولة الاستعلام من كلا الجدولين
        result = await db.rawQuery('''
          SELECT 
            date(date) as sale_date,
            SUM(total_amount) as daily_sales,
            SUM(total_profit) as daily_profit,
            COUNT(*) as daily_count
          FROM sales
          WHERE date >= date('now', '-7 days')
          GROUP BY date(date)
          UNION ALL
          SELECT 
            date(date) as sale_date,
            SUM(total_amount) as daily_sales,
            SUM(total_profit) as daily_profit,
            COUNT(*) as daily_count
          FROM sales_archive
          WHERE date >= date('now', '-7 days')
          GROUP BY date(date)
          ORDER BY sale_date ASC
        ''');
      } catch (e) {
        // Fallback if sales_archive doesn't exist
        log('Warning: sales_archive error in weekly data: $e');
        result = await db.rawQuery('''
          SELECT 
            date(date) as sale_date,
            SUM(total_amount) as daily_sales,
            SUM(total_profit) as daily_profit,
            COUNT(*) as daily_count
          FROM sales
          WHERE date >= date('now', '-7 days')
          GROUP BY date(date)
          ORDER BY sale_date ASC
        ''');
      }

      _weeklySalesData = [];
      final now = DateTime.now();

      // Group results by date (combining duplicates from UNION)
      Map<String, Map<String, dynamic>> aggregatedData = {};
      for (var item in result) {
        final dateKey = item['sale_date'] as String?;
        if (dateKey != null) {
          if (aggregatedData.containsKey(dateKey)) {
            // Aggregate duplicates
            aggregatedData[dateKey]!['daily_sales'] =
                ((aggregatedData[dateKey]!['daily_sales'] as num?) ?? 0) +
                ((item['daily_sales'] as num?) ?? 0);
            aggregatedData[dateKey]!['daily_profit'] =
                ((aggregatedData[dateKey]!['daily_profit'] as num?) ?? 0) +
                ((item['daily_profit'] as num?) ?? 0);
            aggregatedData[dateKey]!['daily_count'] =
                ((aggregatedData[dateKey]!['daily_count'] as int?) ?? 0) +
                ((item['daily_count'] as int?) ?? 0);
          } else {
            aggregatedData[dateKey] = item;
          }
        }
      }

      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateStr = _formatDateForSQL(date);

        final dailyData =
            aggregatedData[dateStr] ??
            {
              'sale_date': dateStr,
              'daily_sales': 0,
              'daily_profit': 0,
              'daily_count': 0,
            };

        _weeklySalesData.add({
          'date': dateStr,
          'sales': (dailyData['daily_sales'] as num?)?.toDouble() ?? 0,
          'profit': (dailyData['daily_profit'] as num?)?.toDouble() ?? 0,
          'count': dailyData['daily_count'] as int? ?? 0,
          'dayName': _getShortDayName(date.weekday),
        });
      }
    } catch (e) {
      log('Error loading weekly data: $e');
      _createEmptyWeeklyData();
    }
  }

  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ دوال مساعدة إضافية █████████████████████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████

  String _getDisplayUnit(String? baseUnit) {
    switch (baseUnit) {
      case 'piece':
        return 'قطعة';
      case 'kg':
        return 'كيلو';
      default:
        return 'وحدة';
    }
  }

  String _formatDateForSQL(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _getShortDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'الإثنين';
      case 2:
        return 'الثلاثاء';
      case 3:
        return 'الأربعاء';
      case 4:
        return 'الخميس';
      case 5:
        return 'الجمعة';
      case 6:
        return 'السبت';
      case 7:
        return 'الأحد';
      default:
        return '--';
    }
  }

  void _createEmptyWeeklyData() {
    _weeklySalesData = [];
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      _weeklySalesData.add({
        'date': _formatDateForSQL(date),
        'sales': 0.0,
        'profit': 0.0,
        'count': 0,
        'dayName': _getShortDayName(date.weekday),
      });
    }
  }

  void _debugCalculations() {
    log('''
    ===== فحص الحسابات =====
    1. إجمالي المبيعات: $_totalSalesAmount
    2. المبيعات النقدية: $_cashSalesAmount
    3. المبيعات الآجلة: $_creditSalesAmount
    4. المجموع المفترض: ${_cashSalesAmount + _creditSalesAmount}
    5. الفرق: ${(_totalSalesAmount - (_cashSalesAmount + _creditSalesAmount)).toStringAsFixed(2)}
    
    6. إجمالي الأرباح: $_totalProfit
    7. الأرباح النقدية: $_totalCashProfit
    8. إجمالي المصاريف: $_totalExpensesAll
    9. المصاريف النقدية: $_totalCashExpenses
    
    10. صافي الربح (الأرباح - المصاريف): $_netProfit
    11. صافي الربح النقدي (أرباح نقدية - مصاريف نقدية): $_netCashProfit
    12. إجمالي العملاء: $_totalCustomers
    
    = الحسابات الدقيقة =
    - صافي الربح المحسوب يدوياً: ${(_totalProfit - _totalExpensesAll).toStringAsFixed(2)}
    - هل يتطابق؟ ${(_netProfit - (_totalProfit - _totalExpensesAll)).abs() < 0.01 ? '✅ نعم' : '❌ لا'}
    ====================
    ''');
  }

  // دالة لاستخدامها في التقارير لضمان الحصول على القيم الصحيحة
  Map<String, dynamic> getCorrectedStatistics() {
    // إعادة حساب لحظة الاستدعاء للتأكد من الدقة
    double correctedNetProfit = _totalProfit - _totalExpensesAll;
    double correctedNetCashProfit = _totalCashProfit - _totalCashExpenses;

    return {
      'totalSales': _totalSalesAmount,
      'totalProfit': _totalProfit,
      'cashSales': _cashSalesAmount,
      'creditSales': _creditSalesAmount,
      'totalExpensesAll': _totalExpensesAll,
      'totalCashExpenses': _totalCashExpenses,
      'netProfit': correctedNetProfit,
      'netCashProfit': correctedNetCashProfit,
      'adjustedNetProfit': correctedNetProfit,
      'salesCount': _salesCount,
      'profitPercentage': _profitPercentage,
      'bestSalesDay': _bestSalesDay ?? 'لا يوجد',
      'averageSale': _salesCount > 0 ? _totalSalesAmount / _salesCount : 0,
      'totalCustomers': _totalCustomers, // تمت الإضافة
    };
  }

  // دالة لمسح الحسابات (للإعادة إلى الصفر)
  void resetAllCalculations() {
    _totalSalesAmount = 0;
    _totalProfit = 0;
    _salesCount = 0;
    _profitPercentage = 0;
    _cashSalesAmount = 0;
    _creditSalesAmount = 0;
    _totalCustomers = 0; // تمت الإضافة
    _bestSalesDay = null;
    _totalCashProfit = 0;
    _totalExpensesAll = 0;
    _totalCashExpenses = 0;
    _netCashProfit = 0;
    _adjustedNetProfit = 0;
    _netProfit = 0;

    notifyListeners();
  }
}
