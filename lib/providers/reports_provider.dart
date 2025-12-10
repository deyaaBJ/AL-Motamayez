// reports_provider.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';

class ReportsProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  Future<void> initialize() async {
    print('Initializing ReportsProvider...');
    // await deleteOldCashSales();
  }

  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ الحالات والمتغيرات █████████████████████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████

  // حالة التحميل للشاشة الرئيسية
  bool _isLoadingReports = false;
  bool get isLoadingReports => _isLoadingReports;

  // الإحصائيات الرئيسية
  double _totalSalesAmount = 0;
  double _totalProfit = 0;
  int _salesCount = 0;
  double _averageSaleAmount = 0;
  double _profitPercentage = 0;
  double _cashSalesAmount = 0;
  double _creditSalesAmount = 0;
  int _totalCustomers = 0;
  String? _bestSalesDay;
  double _highestSaleAmount = 0;
  double _lowestSaleAmount = 0;

  // Getters للإحصائيات
  double get totalSalesAmount => _totalSalesAmount;
  double get totalProfit => _totalProfit;
  int get salesCount => _salesCount;
  double get averageSaleAmount => _averageSaleAmount;
  double get profitPercentage => _profitPercentage;
  double get cashSalesAmount => _cashSalesAmount;
  double get creditSalesAmount => _creditSalesAmount;
  int get totalCustomers => _totalCustomers;
  String? get bestSalesDay => _bestSalesDay;
  double get highestSaleAmount => _highestSaleAmount;
  double get lowestSaleAmount => _lowestSaleAmount;

  // المنتجات والعملاء الأكثر مبيعاً
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _topCustomers = [];
  List<Map<String, dynamic>> get topProducts => _topProducts;
  List<Map<String, dynamic>> get topCustomers => _topCustomers;

  // بيانات المبيعات اليومية للأسبوع (ثابتة - دائماً آخر 7 أيام)
  List<Map<String, dynamic>> _weeklySalesData = [];
  List<Map<String, dynamic>> get weeklySalesData => _weeklySalesData;

  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ الدوال الرئيسية ████████████████████████████████████████████████████████████
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
    } catch (e) {
      print('Error loading reports data: $e');
    }

    _isLoadingReports = false;
    notifyListeners();
  }

  // فلترة حسب فترة محددة (اليوم، الأسبوع، الشهر، السنة)
  Future<void> filterByPeriod(String period) async {
    _isLoadingReports = true;
    notifyListeners();

    try {
      await _filterSales(period);
    } catch (e) {
      print('Error filtering reports: $e');
      await loadReportsData();
    }

    _isLoadingReports = false;
    notifyListeners();
  }

  // فلترة حسب شهر محدد وسنة محددة
  Future<void> filterBySpecificMonth(int month, int year) async {
    _isLoadingReports = true;
    notifyListeners();

    try {
      await _filterSales('specific-month', month: month, year: year);
    } catch (e) {
      print('Error in filterBySpecificMonth: $e');
      await loadReportsData();
    }

    _isLoadingReports = false;
    notifyListeners();
  }

  // فلترة حسب سنة محددة
  Future<void> filterBySpecificYear(int year) async {
    _isLoadingReports = true;
    notifyListeners();

    try {
      await _filterSales('specific-year', year: year);
    } catch (e) {
      print('Error in filterBySpecificYear: $e');
      await loadReportsData();
    }

    _isLoadingReports = false;
    notifyListeners();
  }

  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ دوال تحميل البيانات ████████████████████████████████████████████████████████
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
            WHEN p.base_unit = 'piece' THEN 
              CASE 
                WHEN si.unit_type = 'piece' THEN si.quantity
                WHEN si.unit_type = 'kg' THEN si.quantity
                WHEN si.unit_type = 'custom' AND pu.contain_qty IS NOT NULL THEN si.quantity * pu.contain_qty
                ELSE si.quantity
              END
            WHEN p.base_unit = 'kg' THEN 
              CASE 
                WHEN si.unit_type = 'piece' THEN si.quantity
                WHEN si.unit_type = 'kg' THEN si.quantity
                WHEN si.unit_type = 'custom' AND pu.contain_qty IS NOT NULL THEN si.quantity * pu.contain_qty
                ELSE si.quantity
              END
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
      ORDER BY total_revenue DESC, sale_count DESC
      LIMIT 10
    ''');

      _topProducts =
          result.map((row) {
            String displayUnit = _getDisplayUnit(row['base_unit'] as String?);

            return {
              'name': row['name'] as String? ?? 'غير معروف',
              'quantity': (row['total_quantity'] as num?)?.toDouble() ?? 0,
              'sale_count': row['sale_count'] as int? ?? 0,
              'revenue': (row['total_revenue'] as num?)?.toDouble() ?? 0,
              'profit': (row['total_profit'] as num?)?.toDouble() ?? 0,
              'unit': displayUnit,
              'base_unit': row['base_unit'] as String? ?? 'piece',
            };
          }).toList();

      print('تم تحميل ${_topProducts.length} منتج من أفضل المنتجات مبيعاً');
    } catch (e) {
      print('Error in _loadTopProducts: $e');
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
        WHERE s.date >= date('now', '-30 days')
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
      print('Error in _loadTopCustomers: $e');
      _topCustomers = [];
    }
  }

  Future<void> _loadWeeklySalesData() async {
    try {
      final db = await _dbHelper.db;

      // دائماً نحمّل آخر 7 أيام بغض النظر عن الفلتر
      final result = await db.rawQuery('''
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

      // إعادة تهيئة البيانات
      _weeklySalesData = [];

      // إنشاء بيانات لآخر 7 أيام
      final now = DateTime.now();
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateStr = _formatDateForSQL(date);

        // البحث عن بيانات اليوم
        var dailyData = result.firstWhere(
          (item) => item['sale_date'] == dateStr,
          orElse:
              () => {
                'sale_date': dateStr,
                'daily_sales': 0,
                'daily_profit': 0,
                'daily_count': 0,
              },
        );

        _weeklySalesData.add({
          'date': dateStr,
          'sales': (dailyData['daily_sales'] as num?)?.toDouble() ?? 0,
          'profit': (dailyData['daily_profit'] as num?)?.toDouble() ?? 0,
          'count': dailyData['daily_count'] as int? ?? 0,
          'dayName': _getShortDayName(date.weekday),
        });
      }
    } catch (e) {
      print('Error loading weekly data: $e');
      // في حالة الخطأ، إنشاء بيانات فارغة
      _createEmptyWeeklyData();
    }
  }

  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ دوال التصفية ███████████████████████████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████

  // الدالة الرئيسية للفلترة - تم تعديلها لدعم جميع أنواع الفلاتر
  Future<void> _filterSales(String period, {int? month, int? year}) async {
    try {
      final db = await _dbHelper.db;

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
          whereArgs = [now.toIso8601String().substring(0, 7)];
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
        default:
          whereClause = '1';
          whereArgs = [];
      }

      // جلب المبيعات المصفاة
      final filteredSales = await db.rawQuery(
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

      // حساب الإحصائيات
      _calculateStatsFromFilteredData(filteredSales);

      // إعادة تحميل أفضل المنتجات والعملاء حسب الفلترة
      await _loadFilteredTopProducts(period, month: month, year: year);
      await _loadFilteredTopCustomers(period, month: month, year: year);

      print('تم تطبيق الفلتر بنجاح ($period): ${filteredSales.length} فاتورة');
    } catch (e) {
      print('Error in _filterSales: $e');
      rethrow;
    }
  }

  void _calculateStatsFromFilteredData(
    List<Map<String, dynamic>> filteredSales,
  ) {
    _salesCount = filteredSales.length;
    _totalSalesAmount = 0;
    _totalProfit = 0;
    _highestSaleAmount = 0;
    _lowestSaleAmount = double.maxFinite;
    _cashSalesAmount = 0;
    _creditSalesAmount = 0;

    for (var sale in filteredSales) {
      final amount = (sale['total_amount'] as num?)?.toDouble() ?? 0;
      final profit = (sale['total_profit'] as num?)?.toDouble() ?? 0;
      final paymentType = sale['payment_type'] as String?;

      _totalSalesAmount += amount;
      _totalProfit += profit;

      if (amount > _highestSaleAmount) {
        _highestSaleAmount = amount;
      }
      if (amount < _lowestSaleAmount && amount > 0) {
        _lowestSaleAmount = amount;
      }

      // حساب المبيعات النقدية والآجلة
      if (paymentType == 'cash') {
        _cashSalesAmount += amount;
      } else if (paymentType == 'credit') {
        _creditSalesAmount += amount;
      }
    }

    if (_lowestSaleAmount == double.maxFinite) {
      _lowestSaleAmount = 0;
    }

    // متوسط الفاتورة
    _averageSaleAmount = _salesCount > 0 ? _totalSalesAmount / _salesCount : 0;

    // نسبة الربح
    _profitPercentage =
        _totalSalesAmount > 0 ? (_totalProfit / _totalSalesAmount) * 100 : 0;

    // أفضل يوم مبيعات
    _calculateBestSalesDay(filteredSales);

    print(
      'تم حساب الإحصائيات: $_salesCount فاتورة، إجمالي المبيعات: ${_totalSalesAmount.toStringAsFixed(0)}، الربح: ${_totalProfit.toStringAsFixed(0)}',
    );
  }

  void _calculateBestSalesDay(List<Map<String, dynamic>> sales) {
    if (sales.isEmpty) {
      _bestSalesDay = 'لا يوجد بيانات';
      return;
    }

    Map<String, double> dailyTotals = {};

    for (var sale in sales) {
      final dateStr = (sale['date'] as String?)?.split(' ')[0];
      if (dateStr == null) continue;

      dailyTotals[dateStr] =
          (dailyTotals[dateStr] ?? 0) +
          ((sale['total_amount'] as num?)?.toDouble() ?? 0);
    }

    if (dailyTotals.isEmpty) {
      _bestSalesDay = 'لا يوجد بيانات';
      return;
    }

    final bestDayEntry = dailyTotals.entries.reduce(
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

  // تحميل أفضل المنتجات مع الفلاتر الجديدة
  Future<void> _loadFilteredTopProducts(
    String period, {
    int? month,
    int? year,
  }) async {
    try {
      final db = await _dbHelper.db;

      String whereClause = '';
      List<dynamic> whereArgs = [];

      final now = DateTime.now();

      switch (period) {
        case 'اليوم':
          whereClause = "date(s.date) = date(?)";
          whereArgs = [now.toIso8601String()];
          break;
        case 'الأسبوع':
          final weekAgo = now.subtract(Duration(days: 7));
          whereClause = "date(s.date) >= date(?)";
          whereArgs = [weekAgo.toIso8601String()];
          break;
        case 'الشهر':
          whereClause = "strftime('%Y-%m', s.date) = ?";
          whereArgs = [now.toIso8601String().substring(0, 7)];
          break;
        case 'السنة':
          whereClause = "strftime('%Y', s.date) = ?";
          whereArgs = [now.year.toString()];
          break;
        case 'specific-month':
          whereClause = "strftime('%Y-%m', s.date) = ?";
          String formattedMonth = month!.toString().padLeft(2, '0');
          whereArgs = ['$year-$formattedMonth'];
          break;
        case 'specific-year':
          whereClause = "strftime('%Y', s.date) = ?";
          whereArgs = [year.toString()];
          break;
        default:
          whereClause = "s.date >= date('now', '-30 days')";
          whereArgs = [];
      }

      final result = await db.rawQuery('''
      SELECT 
        p.name,
        p.base_unit,
        SUM(
          CASE 
            WHEN p.base_unit = 'piece' THEN 
              CASE 
                WHEN si.unit_type = 'piece' THEN si.quantity
                WHEN si.unit_type = 'kg' THEN si.quantity
                WHEN si.unit_type = 'custom' AND pu.contain_qty IS NOT NULL THEN si.quantity * pu.contain_qty
                ELSE si.quantity
              END
            WHEN p.base_unit = 'kg' THEN 
              CASE 
                WHEN si.unit_type = 'piece' THEN si.quantity
                WHEN si.unit_type = 'kg' THEN si.quantity
                WHEN si.unit_type = 'custom' AND pu.contain_qty IS NOT NULL THEN si.quantity * pu.contain_qty
                ELSE si.quantity
              END
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
      WHERE $whereClause
      GROUP BY p.id, p.name, p.base_unit
      ORDER BY total_revenue DESC, sale_count DESC
      LIMIT 10
    ''', whereArgs);

      _topProducts =
          result.map((row) {
            String displayUnit = _getDisplayUnit(row['base_unit'] as String?);

            return {
              'name': row['name'] as String? ?? 'غير معروف',
              'quantity': (row['total_quantity'] as num?)?.toDouble() ?? 0,
              'sale_count': row['sale_count'] as int? ?? 0,
              'revenue': (row['total_revenue'] as num?)?.toDouble() ?? 0,
              'profit': (row['total_profit'] as num?)?.toDouble() ?? 0,
              'unit': displayUnit,
              'base_unit': row['base_unit'] as String? ?? 'piece',
            };
          }).toList();
    } catch (e) {
      print('Error in _loadFilteredTopProducts: $e');
      _topProducts = [];
    }
  }

  // تحميل أفضل العملاء مع الفلاتر الجديدة
  Future<void> _loadFilteredTopCustomers(
    String period, {
    int? month,
    int? year,
  }) async {
    try {
      final db = await _dbHelper.db;

      String whereClause = '';
      List<dynamic> whereArgs = [];

      final now = DateTime.now();

      switch (period) {
        case 'اليوم':
          whereClause = "date(s.date) = date(?)";
          whereArgs = [now.toIso8601String()];
          break;
        case 'الأسبوع':
          final weekAgo = now.subtract(Duration(days: 7));
          whereClause = "date(s.date) >= date(?)";
          whereArgs = [weekAgo.toIso8601String()];
          break;
        case 'الشهر':
          whereClause = "strftime('%Y-%m', s.date) = ?";
          whereArgs = [now.toIso8601String().substring(0, 7)];
          break;
        case 'السنة':
          whereClause = "strftime('%Y', s.date) = ?";
          whereArgs = [now.year.toString()];
          break;
        case 'specific-month':
          whereClause = "strftime('%Y-%m', s.date) = ?";
          String formattedMonth = month!.toString().padLeft(2, '0');
          whereArgs = ['$year-$formattedMonth'];
          break;
        case 'specific-year':
          whereClause = "strftime('%Y', s.date) = ?";
          whereArgs = [year.toString()];
          break;
        default:
          whereClause = "s.date >= date('now', '-30 days')";
          whereArgs = [];
      }

      final result = await db.rawQuery('''
        SELECT 
          c.name,
          COUNT(s.id) as purchase_count,
          SUM(s.total_amount) as total_amount,
          SUM(s.total_profit) as total_profit
        FROM sales s
        LEFT JOIN customers c ON s.customer_id = c.id
        WHERE $whereClause AND c.id IS NOT NULL
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
      print('Error in _loadFilteredTopCustomers: $e');
      _topCustomers = [];
    }
  }

  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ دوال مساعدة ████████████████████████████████████████████████████████████████
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
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
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

  // دالة لتصحيح التواريخ (للديبق فقط)
  Future<void> _debugDateIssues() async {
    final db = await _dbHelper.db;

    print('=== Debug Date Issues ===');

    final sampleDates = await db.rawQuery('''
      SELECT date, id FROM sales ORDER BY id DESC LIMIT 5
    ''');

    print('آخر 5 تواريخ في قاعدة البيانات:');
    for (var row in sampleDates) {
      print(' - الفاتورة ${row['id']}: ${row['date']}');
    }

    final currentDate = await db.rawQuery(
      'SELECT date(\'now\') as current_date',
    );
    print('التاريخ الحالي في SQLite: ${currentDate.first['current_date']}');

    print('=== End Debug ===');
  }

  // دالة لحذف الفواتير النقدية القديمة
  Future<void> deleteOldCashSales() async {
    final db = await _dbHelper.db;

    final oldSales = await db.rawQuery("""
    SELECT * FROM sales
    WHERE payment_type = 'cash'
    AND DATE(date) <= DATE('now', '-1 year')
  """);

    for (var sale in oldSales) {
      final saleId = sale['id'];

      await db.delete('sale_items', where: "sale_id = ?", whereArgs: [saleId]);

      await db.delete('sales', where: "id = ?", whereArgs: [saleId]);
    }

    print('تم حذف ${oldSales.length} فاتورة نقدية عمرها أكثر من سنة.');
  }
}
