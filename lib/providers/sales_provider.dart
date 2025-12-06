// providers/sales_provider.dart
import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/sale.dart';

class SalesProvider extends ChangeNotifier {
  int _page = 0;
  final int _limit = 20;
  bool _hasMore = true;
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  final DBHelper _dbHelper = DBHelper();

  // ✅ فصل البيانات: قائمة للكل وقائمة للعرض المصفى
  List<Sale> _allSales = []; // جميع الفواتير المحملة
  List<Sale> _displayedSales = []; // الفواتير المعروضة بعد التصفية

  List<Sale> get sales => _displayedSales; // نعرض المصفاة فقط

  // الفلاتر
  String _selectedPaymentType = 'الكل';
  String _selectedCustomer = 'الكل';
  String _selectedTaxFilter = 'الكل';
  DateTime? _selectedDate;

  // الفلاتر الجديدة للتاريخ المتقدم
  String _dateFilterType = 'day';
  int? _selectedMonth;
  int? _selectedYear;

  // Getters
  String get selectedPaymentType => _selectedPaymentType;
  String get selectedCustomer => _selectedCustomer;
  DateTime? get selectedDate => _selectedDate;
  String get selectedTaxFilter => _selectedTaxFilter;
  String get dateFilterType => _dateFilterType;
  int? get selectedMonth => _selectedMonth;
  int? get selectedYear => _selectedYear;

  List<String> get paymentTypes => ['الكل', 'cash', 'credit'];

  List<String> get customerNames {
    Set<String> names = {'الكل'};
    for (var sale in _allSales) {
      if (sale.customerName != null && sale.customerName!.isNotEmpty) {
        names.add(sale.customerName!);
      } else {
        names.add('بدون عميل');
      }
    }
    return names.toList();
  }

  List<String> get months => [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  List<int> get years {
    final currentYear = DateTime.now().year;
    return List.generate(5, (index) => currentYear - index);
  }

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ Getters جديدة ███████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  // ✅ Getter للحصول على عدد الفواتير المحملة
  int get loadedSalesCount => _allSales.length;

  // ✅ Getter للتحقق مما إذا كانت هناك فواتير محملة
  bool get hasLoadedSales => _allSales.isNotEmpty;

  // ✅ Getter للحصول على نسبة الفلاتر
  String get filteredPercentage {
    if (_allSales.isEmpty) return "0%";
    final percentage =
        (_displayedSales.length / _allSales.length * 100).toInt();
    return "$percentage%";
  }

  // ✅ Getter للحصول على ملخص الفلاتر
  Map<String, dynamic> get filterSummary {
    return {
      'totalLoaded': _allSales.length,
      'displayed': _displayedSales.length,
      'filteredOut': _allSales.length - _displayedSales.length,
      'percentage': filteredPercentage,
    };
  }

  // ✅ دالة لمعرفة ما إذا كانت الفلاتر تعمل
  bool get isFilterActive {
    return _selectedPaymentType != 'الكل' ||
        _selectedCustomer != 'الكل' ||
        _selectedTaxFilter != 'الكل' ||
        _selectedDate != null ||
        _selectedMonth != null ||
        _selectedYear != null ||
        _dateFilterType != 'day';
  }

  // ✅ دالة للحصول على وصف الفلاتر النشطة
  String get activeFiltersDescription {
    final filters = <String>[];

    if (_selectedPaymentType != 'الكل') {
      filters.add('دفع: ${_selectedPaymentType == 'cash' ? 'نقدي' : 'آجل'}');
    }

    if (_selectedCustomer != 'الكل') {
      filters.add('عميل: $_selectedCustomer');
    }

    if (_selectedTaxFilter != 'الكل') {
      filters.add('ضريبة: $_selectedTaxFilter');
    }

    if (_dateFilterType == 'day' && _selectedDate != null) {
      final date = _selectedDate!;
      filters.add('تاريخ: ${date.year}-${date.month}-${date.day}');
    } else if (_dateFilterType == 'month' &&
        _selectedMonth != null &&
        _selectedYear != null) {
      filters.add('شهر: ${months[_selectedMonth! - 1]} $_selectedYear');
    } else if (_dateFilterType == 'year' && _selectedYear != null) {
      filters.add('سنة: $_selectedYear');
    }

    return filters.isEmpty ? 'لا توجد فلاتر' : filters.join('، ');
  }

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ الفلاتر المتقدمة ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  void setDateFilterType(String type) {
    _dateFilterType = type;
    _applyFilters(); // ✅ فقط نطبق الفلاتر على البيانات الموجودة
    notifyListeners();
  }

  void setMonthFilter(int month) {
    _selectedMonth = month;
    _dateFilterType = 'month';
    _applyFilters();
    notifyListeners();
  }

  void setYearFilter(int year) {
    _selectedYear = year;
    _dateFilterType = 'year';
    _applyFilters();
    notifyListeners();
  }

  void clearDateFilter() {
    _selectedDate = null;
    _selectedMonth = null;
    _selectedYear = null;
    _dateFilterType = 'day';
    _applyFilters();
    notifyListeners();
  }

  // دالة مساعدة لبناء استعلام التاريخ
  String _buildDateWhereClause() {
    switch (_dateFilterType) {
      case 'day':
        if (_selectedDate != null) {
          final dateStr = _selectedDate!.toIso8601String().split('T')[0];
          return "date(s.date) = '$dateStr'";
        }
        break;
      case 'month':
        if (_selectedMonth != null && _selectedYear != null) {
          return "strftime('%m', s.date) = '${_selectedMonth!.toString().padLeft(2, '0')}' AND strftime('%Y', s.date) = '$_selectedYear'";
        }
        break;
      case 'year':
        if (_selectedYear != null) {
          return "strftime('%Y', s.date) = '$_selectedYear'";
        }
        break;
    }
    return '1=1';
  }

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ التحميل التدريجي ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  int todaySalesCount = 0;

  Future<void> loadTodaySalesCount() async {
    final db = await _dbHelper.db;
    final result = await db.rawQuery("""
      SELECT COUNT(*) as count 
      FROM sales
      WHERE DATE(date) = DATE('now')
    """);
    todaySalesCount = result.first['count'] as int;
    notifyListeners();
  }

  // ✅ التحميل التدريجي للفواتير (بدون فلاتر في الاستعلام)
  Future<void> fetchSales({bool loadMore = false}) async {
    if (_isLoading || (!_hasMore && loadMore)) return;

    _isLoading = true;
    notifyListeners();

    if (!loadMore) {
      _page = 0;
      _allSales.clear();
      _hasMore = true;
    }

    final db = await _dbHelper.db;

    try {
      // ✅ نطلب كل الفواتير بدون فلاتر للتحميل التدريجي
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
        _allSales.addAll(newSales);
      } else {
        _allSales = newSales;
      }

      _page++;

      // ✅ تطبيق الفلاتر على البيانات الجديدة
      _applyFilters();
    } catch (e) {
      print('Error fetching sales: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ تطبيق الفلاتر على البيانات المحملة
  void _applyFilters() {
    List<Sale> filtered = _allSales;

    // فلترة نوع الدفع
    if (_selectedPaymentType != 'الكل') {
      filtered =
          filtered
              .where(
                (sale) =>
                    sale.paymentType == _selectedPaymentType.toLowerCase(),
              )
              .toList();
    }

    // فلترة العميل
    if (_selectedCustomer != 'الكل') {
      if (_selectedCustomer == 'بدون عميل') {
        filtered = filtered.where((sale) => sale.customerId == null).toList();
      } else {
        filtered =
            filtered
                .where((sale) => sale.customerName == _selectedCustomer)
                .toList();
      }
    }

    // فلترة الضريبة
    if (_selectedTaxFilter != 'الكل') {
      final taxValue = _selectedTaxFilter == 'مضمنه بالضرائب' ? 1 : 0;
      filtered = filtered.where((sale) => sale.showForTax == taxValue).toList();
    }

    // فلترة التاريخ
    if (_dateFilterType == 'day' && _selectedDate != null) {
      final selectedDateStr = _selectedDate!.toIso8601String().split('T')[0];
      filtered =
          filtered.where((sale) {
            final saleDateStr =
                DateTime.parse(sale.date).toIso8601String().split('T')[0];
            return saleDateStr == selectedDateStr;
          }).toList();
    } else if (_dateFilterType == 'month' &&
        _selectedMonth != null &&
        _selectedYear != null) {
      filtered =
          filtered.where((sale) {
            final saleDate = DateTime.parse(sale.date);
            return saleDate.month == _selectedMonth &&
                saleDate.year == _selectedYear;
          }).toList();
    } else if (_dateFilterType == 'year' && _selectedYear != null) {
      filtered =
          filtered.where((sale) {
            final saleDate = DateTime.parse(sale.date);
            return saleDate.year == _selectedYear;
          }).toList();
    }

    _displayedSales = filtered;
  }

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ دوال الفلترة ███████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  void setPaymentTypeFilter(String? value) {
    _selectedPaymentType = value ?? 'الكل';
    _applyFilters();
    notifyListeners();
  }

  void setCustomerFilter(String? value) {
    _selectedCustomer = value ?? 'الكل';
    _applyFilters();
    notifyListeners();
  }

  void setDateFilter(DateTime? date) {
    _selectedDate = date;
    _dateFilterType = 'day';
    _applyFilters();
    notifyListeners();
  }

  void setTaxFilter(String? value) {
    _selectedTaxFilter = value ?? 'الكل';
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _selectedPaymentType = 'الكل';
    _selectedCustomer = 'الكل';
    _selectedTaxFilter = 'الكل';
    _applyFilters();
    notifyListeners();
  }

  void clearAllFilters() {
    _selectedPaymentType = 'الكل';
    _selectedCustomer = 'الكل';
    _selectedTaxFilter = 'الكل';
    _selectedDate = null;
    _selectedMonth = null;
    _selectedYear = null;
    _dateFilterType = 'day';
    _applyFilters();
    notifyListeners();
  }

  void reset() {
    _allSales.clear();
    _displayedSales.clear();
    _isLoading = false;
    _hasMore = true;
    _page = 0;
    _selectedPaymentType = 'الكل';
    _selectedCustomer = 'الكل';
    _selectedDate = null;
    _selectedTaxFilter = 'الكل';
    _selectedMonth = null;
    _selectedYear = null;
    _dateFilterType = 'day';
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

    // عناصر الفاتورة مع معلومات الوحدات
    final itemsResult = await db.rawQuery(
      '''
    SELECT 
      si.*, 
      p.name as product_name,
      p.base_unit as product_base_unit,
      pu.unit_name as custom_unit_name,
      pu.contain_qty as unit_contain_qty
    FROM sale_items si 
    JOIN products p ON si.product_id = p.id 
    LEFT JOIN product_units pu ON si.unit_id = pu.id
    WHERE si.sale_id = ?
  ''',
      [saleId],
    );

    return {'sale': Sale.fromMap(saleResult.first), 'items': itemsResult};
  }

  Future<void> updatePaymentType(
    int saleId,
    String paymentType, {
    int? customerId,
  }) async {
    final db = await _dbHelper.db;

    // تأكد إن القيمة فقط 'cash' أو 'credit'
    if (paymentType != 'cash' && paymentType != 'credit') {
      throw Exception('نوع الدفع غير صالح. يجب أن يكون "cash" أو "credit".');
    }

    // إعداد البيانات للتحديث
    Map<String, dynamic> updateData = {'payment_type': paymentType};

    // إذا كان credit وتم تمرير customerId، أضفه للبيانات
    if (paymentType == 'credit') {
      updateData['customer_id'] = customerId;
    }

    // تنفيذ التحديث في قاعدة البيانات
    int count = await db.update(
      'sales',
      updateData,
      where: 'id = ?',
      whereArgs: [saleId],
    );

    // تحقق إذا لم يتم التحديث لأي سجل
    if (count == 0) {
      throw Exception('فشل التعديل: لم يتم العثور على الفاتورة بالرقم المحدد.');
    }

    notifyListeners();
  }

  Future<void> updateShowForTax(int saleId, bool showForTax) async {
    final db = await _dbHelper.db;

    // إعداد البيانات للتحديث
    Map<String, dynamic> updateData = {
      'show_for_tax': showForTax ? 1 : 0, // 1: نعم، 0: لا
    };

    // تنفيذ التحديث في قاعدة البيانات
    int count = await db.update(
      'sales',
      updateData,
      where: 'id = ?',
      whereArgs: [saleId],
    );

    // تحقق إذا لم يتم التحديث لأي سجل
    if (count == 0) {
      throw Exception('فشل التعديل: لم يتم العثور على الفاتورة بالرقم المحدد.');
    }

    notifyListeners();
  }

  // في ملف SalesProvider
  Future<void> deleteSale(int saleId) async {
    final db = await _dbHelper.db;

    await db.transaction((txn) async {
      // 1. جلب عناصر الفاتورة أولاً
      final saleItems = await txn.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );

      // 2. إرجاع الكميات إلى المخزون
      for (var item in saleItems) {
        final int productId = item['product_id'] as int;
        final double quantity =
            (item['quantity'] is int)
                ? (item['quantity'] as int).toDouble()
                : item['quantity'] as double;
        final String unitType = item['unit_type'] as String;
        final int? unitId = item['unit_id'] as int?;

        double quantityToReturn = quantity;

        // إذا كانت وحدة مخصصة، نحتاج لمعرفة معامل التحويل
        if (unitType == 'custom' && unitId != null) {
          final unitResult = await txn.query(
            'product_units',
            columns: ['contain_qty'],
            where: 'id = ?',
            whereArgs: [unitId],
          );

          if (unitResult.isNotEmpty) {
            final double containQty =
                (unitResult.first['contain_qty'] is int)
                    ? (unitResult.first['contain_qty'] as int).toDouble()
                    : unitResult.first['contain_qty'] as double;
            quantityToReturn = quantity * containQty;
          }
        }

        // إرجاع الكمية إلى المخزون
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity + ? WHERE id = ?',
          [quantityToReturn, productId],
        );
      }

      // 3. حذف عناصر الفاتورة
      await txn.delete('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);

      // 4. حذف الفاتورة الرئيسية
      await txn.delete('sales', where: 'id = ?', whereArgs: [saleId]);
    });

    // 5. إزالة الفاتورة من القائمة المحلية
    sales.removeWhere((sale) => sale.id == saleId);

    notifyListeners();

    print('🗑️ تم حذف الفاتورة #$saleId وإرجاع الكميات إلى المخزون');
  }

  // في product_provider.dart - أضف هذه الدالة
}
