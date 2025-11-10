// providers/sales_provider.dart
import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/sale.dart';

class SalesProvider extends ChangeNotifier {
  int _page = 0;
  final int _limit = 20;
  bool _hasMore = true;
  bool _isLoading = false;

  // Added public getters so UI can read loading/hasMore state
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  final DBHelper _dbHelper = DBHelper();
  List<Sale> _sales = [];
  List<Sale> _filteredSales = [];

  List<Sale> get sales => _filteredSales;

  // الفلاتر
  String _selectedPaymentType = 'الكل';
  String _selectedCustomer = 'الكل';
  DateTime? _selectedDate;

  // Getters for filters
  String get selectedPaymentType => _selectedPaymentType;
  String get selectedCustomer => _selectedCustomer;
  DateTime? get selectedDate => _selectedDate;

  // قيم الفلاتر
  List<String> get paymentTypes => ['الكل', 'cash', 'credit'];

  List<String> get customerNames {
    Set<String> names = {'الكل'};
    for (var sale in _sales) {
      if (sale.customerName != null && sale.customerName!.isNotEmpty) {
        names.add(sale.customerName!);
      } else {
        names.add('بدون عميل');
      }
    }
    return names.toList();
  }

  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ دوال التقارير والإحصائيات الجديدة ██████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████

  // حالات التحميل
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

  // بيانات المبيعات اليومية للأسبوع (للمخطط البياني)
  List<Map<String, dynamic>> _weeklySalesData = [];
  List<Map<String, dynamic>> get weeklySalesData => _weeklySalesData;

  // دوال التقارير الرئيسية
  Future<void> loadReportsData() async {
    _isLoadingReports = true;
    notifyListeners();

    try {
      await Future.wait([
        _loadSalesStats(),
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

  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ الدالة المفقودة filterByPeriod █████████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████

  Future<void> filterByPeriod(String period) async {
    _isLoadingReports = true;
    notifyListeners();

    try {
      // تشغيل الديبق لفحص المشكلة
      await _debugDateIssues();

      final db = await _dbHelper.db;
      String whereClause = '';

      switch (period) {
        case 'اليوم':
          // الحل: استخدام LIKE للبحث عن التواريخ التي تبدأ بتاريخ اليوم
          final today = DateTime.now();
          final todayStr =
              "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
          whereClause = "WHERE date LIKE '$todayStr%'";
          break;
        case 'الأسبوع':
          whereClause = "WHERE date >= date('now', '-7 days')";
          break;
        case 'الشهر':
          whereClause = "WHERE date >= date('now', '-30 days')";
          break;
        case 'السنة':
          whereClause = "WHERE date >= date('now', '-365 days')";
          break;
        default:
          whereClause = "WHERE date >= date('now', '-30 days')";
      }

      print('استخدام فلتر: $whereClause');

      // إعادة تحميل الإحصائيات مع الفلتر
      await _loadFilteredStats(whereClause);
      await _loadFilteredTopProducts(whereClause);
      await _loadFilteredTopCustomers(whereClause);
    } catch (e) {
      print('Error filtering reports: $e');
      // في حالة الخطأ، استخدام الحل البديل
      await _filterByPeriodAlternative(period);
    }

    _isLoadingReports = false;
    notifyListeners();
  }

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
    } catch (e) {
      print('Error in alternative filter: $e');
      // إذا فشل كل شيء، إعادة تحميل البيانات الافتراضية
      await loadReportsData();
    }
  }

  DateTime _parseSaleDate(String dateStr) {
    try {
      // محاولة التحويل المباشر
      return DateTime.parse(dateStr);
    } catch (e) {
      // إذا فشل، محاولة تنسيقات أخرى
      try {
        // إذا كان التاريخ يحتوي على وقت أيضاً
        if (dateStr.contains(' ')) {
          return DateTime.parse(dateStr.split(' ')[0]);
        }
        // إذا كان بتنسيق مختلف
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

  void _calculateStatsFromFilteredData(
    List<Map<String, dynamic>> filteredSales,
  ) {
    _salesCount = filteredSales.length;
    _totalSalesAmount = 0;
    _totalProfit = 0;
    _highestSaleAmount = 0;
    _lowestSaleAmount = double.maxFinite;

    for (var sale in filteredSales) {
      final amount = (sale['total_amount'] as num?)?.toDouble() ?? 0;
      final profit = (sale['total_profit'] as num?)?.toDouble() ?? 0;

      _totalSalesAmount += amount;
      _totalProfit += profit;

      if (amount > _highestSaleAmount) {
        _highestSaleAmount = amount;
      }
      if (amount < _lowestSaleAmount && amount > 0) {
        _lowestSaleAmount = amount;
      }
    }

    if (_lowestSaleAmount == double.maxFinite) {
      _lowestSaleAmount = 0;
    }

    _averageSaleAmount = _salesCount > 0 ? _totalSalesAmount / _salesCount : 0;
    _profitPercentage =
        _totalSalesAmount > 0 ? (_totalProfit / _totalSalesAmount) * 100 : 0;

    // حساب المبيعات النقدية والآجلة
    _cashSalesAmount = 0;
    _creditSalesAmount = 0;

    for (var sale in filteredSales) {
      final paymentType = sale['payment_type'] as String?;
      final amount = (sale['total_amount'] as num?)?.toDouble() ?? 0;

      if (paymentType == 'cash') {
        _cashSalesAmount += amount;
      } else if (paymentType == 'credit') {
        _creditSalesAmount += amount;
      }
    }

    // إعادة تعيين القوائم
    _topProducts = [];
    _topCustomers = [];

    print(
      'تم تطبيق الفلتر بنجاح: $_salesCount فاتورة، ${_totalSalesAmount.toStringAsFixed(0)} ل.س',
    );
  }

  Future<void> _loadSalesStats() async {
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
      WHERE date >= date('now', '-30 days')  -- آخر 30 يوم
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
          _totalSalesAmount > 0 ? (_totalProfit / _totalSalesAmount) * 100 : 0;
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
      GROUP BY date
      ORDER BY total DESC
      LIMIT 1
    ''');

    if (bestDayResult.isNotEmpty) {
      final bestDay = bestDayResult.first;
      final dateString = bestDay['date'] as String?;
      if (dateString != null) {
        final date = DateTime.parse(dateString);
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
      }
    }
  }

  Future<void> _loadTopProducts() async {
    final db = await _dbHelper.db;

    final result = await db.rawQuery('''
      SELECT 
        p.name,
        p.barcode,
        SUM(si.quantity) as total_quantity,
        SUM(si.subtotal) as total_revenue
      FROM sale_items si
      JOIN products p ON si.product_id = p.id
      JOIN sales s ON si.sale_id = s.id
      WHERE s.date >= date('now', '-30 days')
      GROUP BY p.id, p.name, p.barcode
      ORDER BY total_quantity DESC
      LIMIT 10
    ''');

    _topProducts =
        result.map((row) {
          return {
            'name': row['name'] as String? ?? 'غير معروف',
            'barcode': row['barcode'] as String? ?? '',
            'quantity': row['total_quantity'] as int? ?? 0,
            'revenue': (row['total_revenue'] as num?)?.toDouble() ?? 0,
          };
        }).toList();
  }

  Future<void> _loadTopCustomers() async {
    final db = await _dbHelper.db;

    final result = await db.rawQuery('''
      SELECT 
        c.name,
        c.phone,
        COUNT(s.id) as purchase_count,
        SUM(s.total_amount) as total_amount,
        SUM(s.total_profit) as total_profit
      FROM sales s
      JOIN customers c ON s.customer_id = c.id
      WHERE s.date >= date('now', '-30 days')
      GROUP BY c.id, c.name, c.phone
      ORDER BY total_amount DESC
      LIMIT 10
    ''');

    _topCustomers =
        result.map((row) {
          return {
            'name': row['name'] as String? ?? 'غير معروف',
            'phone': row['phone'] as String? ?? '',
            'purchase_count': row['purchase_count'] as int? ?? 0,
            'total_amount': (row['total_amount'] as num?)?.toDouble() ?? 0,
            'total_profit': (row['total_profit'] as num?)?.toDouble() ?? 0,
          };
        }).toList();
  }

  // تأكد من إضافة هذه الدوال في SalesProvider
  Future<void> _loadWeeklySalesData() async {
    try {
      final db = await _dbHelper.db;

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

  // أضف هذه الدالة في SalesProvider
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

    // اختبار فلتر اليوم
    final todayResult = await db.rawQuery('''
    SELECT COUNT(*) as count FROM sales WHERE date = date('now')
  ''');
    print('عدد الفواتير بفلتر اليوم: ${todayResult.first['count']}');

    print('=== End Debug ===');
  }

  Future<void> _loadFilteredStats(String whereClause) async {
    try {
      final db = await _dbHelper.db;

      final salesResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as count,
        SUM(total_amount) as total_sales,
        SUM(total_profit) as total_profit,
        MAX(total_amount) as highest_sale,
        MIN(total_amount) as lowest_sale
      FROM sales
      $whereClause
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

      final paymentResult = await db.rawQuery('''
      SELECT 
        payment_type,
        SUM(total_amount) as amount
      FROM sales
      $whereClause
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

      print(
        'الإحصائيات المصفاة: $_salesCount فاتورة، ${_totalSalesAmount.toStringAsFixed(0)} ل.س',
      );
    } catch (e) {
      print('Error in _loadFilteredStats: $e');
      throw e;
    }
  }

  Future<void> _loadFilteredTopProducts(String whereClause) async {
    final db = await _dbHelper.db;

    final result = await db.rawQuery('''
      SELECT 
        p.name,
        p.barcode,
        SUM(si.quantity) as total_quantity,
        SUM(si.subtotal) as total_revenue
      FROM sale_items si
      JOIN products p ON si.product_id = p.id
      JOIN sales s ON si.sale_id = s.id
      $whereClause
      GROUP BY p.id, p.name, p.barcode
      ORDER BY total_quantity DESC
      LIMIT 10
    ''');

    _topProducts =
        result.map((row) {
          return {
            'name': row['name'] as String? ?? 'غير معروف',
            'barcode': row['barcode'] as String? ?? '',
            'quantity': row['total_quantity'] as int? ?? 0,
            'revenue': (row['total_revenue'] as num?)?.toDouble() ?? 0,
          };
        }).toList();
  }

  Future<void> _loadFilteredTopCustomers(String whereClause) async {
    final db = await _dbHelper.db;

    final result = await db.rawQuery('''
      SELECT 
        c.name,
        c.phone,
        COUNT(s.id) as purchase_count,
        SUM(s.total_amount) as total_amount,
        SUM(s.total_profit) as total_profit
      FROM sales s
      JOIN customers c ON s.customer_id = c.id
      $whereClause
      GROUP BY c.id, c.name, c.phone
      ORDER BY total_amount DESC
      LIMIT 10
    ''');

    _topCustomers =
        result.map((row) {
          return {
            'name': row['name'] as String? ?? 'غير معروف',
            'phone': row['phone'] as String? ?? '',
            'purchase_count': row['purchase_count'] as int? ?? 0,
            'total_amount': (row['total_amount'] as num?)?.toDouble() ?? 0,
            'total_profit': (row['total_profit'] as num?)?.toDouble() ?? 0,
          };
        }).toList();
  }

  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ الدوال الأصلية (الحالية) ███████████████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████

  Future<void> fetchSales({bool loadMore = false}) async {
    if (_isLoading || (!_hasMore && loadMore)) return;

    _isLoading = true;
    notifyListeners();

    if (!loadMore) {
      _page = 0;
      _sales.clear();
    }

    final db = await _dbHelper.db;
    final result = await db.rawQuery('''
    SELECT s.*, c.name as customer_name 
    FROM sales s 
    LEFT JOIN customers c ON s.customer_id = c.id 
    ORDER BY s.date DESC
    LIMIT $_limit OFFSET ${_page * _limit}
  ''');

    final newSales = result.map((e) => Sale.fromMap(e)).toList();

    if (newSales.length < _limit) {
      _hasMore = false;
    }

    if (loadMore) {
      _sales.addAll(newSales);
    } else {
      _sales = newSales;
    }

    _filteredSales = _sales;
    _page++;
    _isLoading = false;

    notifyListeners();
  }

  void setPaymentTypeFilter(String? value) {
    _selectedPaymentType = value ?? 'الكل';
    _applyFilters();
  }

  void setCustomerFilter(String? value) {
    _selectedCustomer = value ?? 'الكل';
    _applyFilters();
  }

  void setDateFilter(DateTime? date) {
    _selectedDate = date;
    _applyFilters();
  }

  void clearFilters() {
    _selectedPaymentType = 'الكل';
    _selectedCustomer = 'الكل';
    _selectedDate = null;
    _filteredSales = _sales;
    notifyListeners();
  }

  void _applyFilters() {
    _filteredSales =
        _sales.where((sale) {
          // فلتر نوع الدفع
          if (_selectedPaymentType != 'الكل') {
            if (sale.paymentType != _selectedPaymentType) {
              return false;
            }
          }

          // فلتر العميل
          if (_selectedCustomer != 'الكل') {
            String customerName = sale.customerName ?? 'بدون عميل';
            if (customerName != _selectedCustomer) {
              return false;
            }
          }

          // فلتر التاريخ
          if (_selectedDate != null) {
            try {
              final saleDate = DateTime.parse(sale.date);
              if (saleDate.year != _selectedDate!.year ||
                  saleDate.month != _selectedDate!.month ||
                  saleDate.day != _selectedDate!.day) {
                return false;
              }
            } catch (e) {
              return false;
            }
          }

          return true;
        }).toList();

    notifyListeners();
  }

  // جلب تفاصيل الفاتورة
  Future<Map<String, dynamic>> getSaleDetails(int saleId) async {
    final db = await _dbHelper.db;

    // بيانات الفاتورة الأساسية
    final saleResult = await db.rawQuery(
      '''
      SELECT s.*, c.name as customer_name, c.phone as customer_phone
      FROM sales s 
      LEFT JOIN customers c ON s.customer_id = c.id 
      WHERE s.id = ?
    ''',
      [saleId],
    );

    if (saleResult.isEmpty) {
      throw Exception('الفاتورة غير موجودة');
    }

    // عناصر الفاتورة
    final itemsResult = await db.rawQuery(
      '''
      SELECT si.*, p.name as product_name 
      FROM sale_items si 
      JOIN products p ON si.product_id = p.id 
      WHERE si.sale_id = ?
    ''',
      [saleId],
    );

    return {'sale': Sale.fromMap(saleResult.first), 'items': itemsResult};
  }
}
