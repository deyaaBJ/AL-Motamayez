// reports_provider.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';

class ReportsProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

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
        _loadSalesStats(),
        _loadTopProducts(),
        _loadTopCustomers(),
        _loadWeeklySalesData(), // تحميل بيانات الأسبوع الثابتة
      ]);
    } catch (e) {
      print('Error loading reports data: $e');
    }

    _isLoadingReports = false;
    notifyListeners();
  }

  Future<void> filterByPeriod(String period) async {
    _isLoadingReports = true;
    notifyListeners();

    try {
      // استخدام الطريقة البديلة للفلترة
      await _filterByPeriodAlternative(period);
    } catch (e) {
      print('Error filtering reports: $e');
      // في حالة الخطأ، إعادة تحميل البيانات الافتراضية
      await loadReportsData();
    }

    _isLoadingReports = false;
    notifyListeners();
  }

  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ دوال تحميل البيانات ████████████████████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████

  Future<void> _loadSalesStats() async {
    try {
      final db = await _dbHelper.db;

      // إجمالي المبيعات والأرباح
      final salesResult = await db.rawQuery('''
        SELECT 
          COUNT(*) as count,
          SUM(total_amount) as total_sales,
          SUM(total_profit) as total_profit,
          MAX(total_amount) as highest_sale,
          MIN(total_amount) as lowest_sale
        FROM sales
        WHERE date >= date('now', '-30 days')
      ''');

      if (salesResult.isNotEmpty) {
        final data = salesResult.first;
        _salesCount = data['count'] as int? ?? 0;
        _totalSalesAmount = (data['total_sales'] as num?)?.toDouble() ?? 0;
        _totalProfit = (data['total_profit'] as num?)?.toDouble() ?? 0;
        _highestSaleAmount = (data['highest_sale'] as num?)?.toDouble() ?? 0;
        _lowestSaleAmount = (data['lowest_sale'] as num?)?.toDouble() ?? 0;

        _averageSaleAmount =
            _salesCount > 0 ? _totalSalesAmount / _salesCount : 0;
        _profitPercentage =
            _totalSalesAmount > 0
                ? (_totalProfit / _totalSalesAmount) * 100
                : 0;
      }

      // المبيعات النقدية والآجلة
      final paymentResult = await db.rawQuery('''
        SELECT 
          payment_type,
          SUM(total_amount) as amount
        FROM sales
        WHERE date >= date('now', '-30 days')
        GROUP BY payment_type
      ''');

      _cashSalesAmount = 0;
      _creditSalesAmount = 0;

      for (var row in paymentResult) {
        if (row['payment_type'] == 'cash') {
          _cashSalesAmount = (row['amount'] as num?)?.toDouble() ?? 0;
        } else if (row['payment_type'] == 'credit') {
          _creditSalesAmount = (row['amount'] as num?)?.toDouble() ?? 0;
        }
      }

      // إجمالي عدد العملاء
      final customersResult = await db.rawQuery('''
        SELECT COUNT(DISTINCT id) as count FROM customers
      ''');
      _totalCustomers = customersResult.first['count'] as int? ?? 0;

      // أفضل يوم مبيعات
      final bestDayResult = await db.rawQuery('''
        SELECT date, SUM(total_amount) as total
        FROM sales
        WHERE date >= date('now', '-30 days')
        GROUP BY date
        ORDER BY total DESC
        LIMIT 1
      ''');

      if (bestDayResult.isNotEmpty) {
        final bestDay = bestDayResult.first;
        final dateString = bestDay['date'] as String?;
        if (dateString != null) {
          try {
            final date = DateTime.parse(dateString.split(' ')[0]);
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
      } else {
        _bestSalesDay = 'لا يوجد بيانات';
      }
    } catch (e) {
      print('Error in _loadSalesStats: $e');
    }
  }

  // reports_provider.dart - عدّل دالة _loadTopProducts

  Future<void> _loadTopProducts() async {
    try {
      final db = await _dbHelper.db;

      final result = await db.rawQuery('''
      SELECT 
        p.name,
        p.base_unit,
        -- حساب الكمية الإجمالية مع مراعاة نوع الوحدة
        SUM(
          CASE 
            -- إذا كانت الوحدة الأساسية هي القطعة
            WHEN p.base_unit = 'piece' THEN 
              CASE 
                WHEN si.unit_type = 'piece' THEN si.quantity
                WHEN si.unit_type = 'kg' THEN si.quantity  -- لا يمكن التحويل بدون معرفة الوزن
                WHEN si.unit_type = 'custom' AND pu.contain_qty IS NOT NULL THEN si.quantity * pu.contain_qty
                ELSE si.quantity
              END
            -- إذا كانت الوحدة الأساسية هي الكيلو
            WHEN p.base_unit = 'kg' THEN 
              CASE 
                WHEN si.unit_type = 'piece' THEN si.quantity  -- لا يمكن التحويل بدون معرفة الوزن
                WHEN si.unit_type = 'kg' THEN si.quantity
                WHEN si.unit_type = 'custom' AND pu.contain_qty IS NOT NULL THEN si.quantity * pu.contain_qty
                ELSE si.quantity
              END
            ELSE si.quantity
          END
        ) as total_quantity,
        
        -- حساب عدد المرات التي تم بيع المنتج فيها (بغض النظر عن الكمية)
        COUNT(DISTINCT si.sale_id) as sale_count,
        
        -- الإيراد الإجمالي
        SUM(si.subtotal) as total_revenue,
        
        -- الربح الإجمالي
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
            // تحديد نوع الوحدة للعرض
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

  // دالة مساعدة لتحويل الوحدة الأساسية إلى نص مفهوم
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

  // وأيضاً عدّل دالة _loadFilteredTopProducts بنفس الطريقة

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

  Future<void> _filterByPeriodAlternative(String period) async {
    try {
      final db = await _dbHelper.db;

      // جلب جميع المبيعات أولاً
      final allSales = await db.rawQuery('SELECT * FROM sales');

      final now = DateTime.now();
      List<Map<String, dynamic>> filteredSales = [];

      for (var sale in allSales) {
        final saleDateStr = sale['date'] as String?;
        if (saleDateStr == null) continue;

        try {
          // تحويل تاريخ الفاتورة إلى DateTime
          final saleDate = _parseSaleDate(saleDateStr);
          bool shouldInclude = false;

          switch (period) {
            case 'اليوم':
              shouldInclude =
                  saleDate.year == now.year &&
                  saleDate.month == now.month &&
                  saleDate.day == now.day;
              break;
            case 'الأسبوع':
              final weekAgo = now.subtract(const Duration(days: 7));
              shouldInclude =
                  saleDate.isAfter(weekAgo) || _isSameDay(saleDate, weekAgo);
              break;
            case 'الشهر':
              final monthAgo = now.subtract(const Duration(days: 30));
              shouldInclude =
                  saleDate.isAfter(monthAgo) || _isSameDay(saleDate, monthAgo);
              break;
            case 'السنة':
              final yearAgo = now.subtract(const Duration(days: 365));
              shouldInclude =
                  saleDate.isAfter(yearAgo) || _isSameDay(saleDate, yearAgo);
              break;
            default:
              shouldInclude = true;
          }

          if (shouldInclude) {
            filteredSales.add(sale);
          }
        } catch (e) {
          print('Error parsing date for sale ${sale['id']}: $e');
        }
      }

      // حساب الإحصائيات من البيانات المصفاة
      _calculateStatsFromFilteredData(filteredSales);

      // إعادة تحميل المنتجات والعملاء بعد التصفية
      await _loadFilteredTopProducts(period);
      await _loadFilteredTopCustomers(period);

      // ملاحظة: لا نعيد تحميل بيانات الأسبوع - نبقيها كما هي لآخر 7 أيام
      print('بيانات الأسبوع تبقى ثابتة لعرض آخر 7 أيام');
    } catch (e) {
      print('Error in alternative filter: $e');
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

    _averageSaleAmount = _salesCount > 0 ? _totalSalesAmount / _salesCount : 0;
    _profitPercentage =
        _totalSalesAmount > 0 ? (_totalProfit / _totalSalesAmount) * 100 : 0;

    print(
      'تم تطبيق الفلتر بنجاح: $_salesCount فاتورة، ${_totalSalesAmount.toStringAsFixed(0)} ل.س',
    );
  }

  Future<void> _loadFilteredTopProducts(String period) async {
    try {
      final db = await _dbHelper.db;
      final whereClause = _getWhereClauseForPeriod(period);

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
      $whereClause
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
    } catch (e) {
      print('Error in _loadFilteredTopProducts: $e');
      _topProducts = [];
    }
  }

  Future<void> _loadFilteredTopCustomers(String period) async {
    try {
      final db = await _dbHelper.db;
      final whereClause = _getWhereClauseForPeriod(period);

      final result = await db.rawQuery('''
        SELECT 
          c.name,
          COUNT(s.id) as purchase_count,
          SUM(s.total_amount) as total_amount,
          SUM(s.total_profit) as total_profit
        FROM sales s
        LEFT JOIN customers c ON s.customer_id = c.id
        $whereClause
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
      print('Error in _loadFilteredTopCustomers: $e');
      _topCustomers = [];
    }
  }

  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ دوال مساعدة ████████████████████████████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████

  String _getWhereClauseForPeriod(String period) {
    switch (period) {
      case 'اليوم':
        return "WHERE date >= date('now', 'start of day')";
      case 'الأسبوع':
        return "WHERE date >= date('now', '-7 days')";
      case 'الشهر':
        return "WHERE date >= date('now', '-30 days')";
      case 'السنة':
        return "WHERE date >= date('now', '-365 days')";
      default:
        return "WHERE date >= date('now', '-30 days')";
    }
  }

  DateTime _parseSaleDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      try {
        if (dateStr.contains(' ')) {
          return DateTime.parse(dateStr.split(' ')[0]);
        }
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          return DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }
      } catch (e2) {
        print('Failed to parse date: $dateStr');
      }
      return DateTime.now();
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
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

    // فحص التواريخ في قاعدة البيانات
    final sampleDates = await db.rawQuery('''
      SELECT date, id FROM sales ORDER BY id DESC LIMIT 5
    ''');

    print('آخر 5 تواريخ في قاعدة البيانات:');
    for (var row in sampleDates) {
      print(' - الفاتورة ${row['id']}: ${row['date']}');
    }

    // فحص التاريخ الحالي في SQLite
    final currentDate = await db.rawQuery(
      'SELECT date(\'now\') as current_date',
    );
    print('التاريخ الحالي في SQLite: ${currentDate.first['current_date']}');

    print('=== End Debug ===');
  }
}
