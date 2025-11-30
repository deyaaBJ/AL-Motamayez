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
  String _selectedTaxFilter = 'الكل';
  DateTime? _selectedDate;

  // الفلاتر الجديدة للتاريخ المتقدم
  String _dateFilterType = 'day'; // 'day', 'month', 'year'
  int? _selectedMonth; // 1-12
  int? _selectedYear;

  // Getters for filters
  String get selectedPaymentType => _selectedPaymentType;
  String get selectedCustomer => _selectedCustomer;
  DateTime? get selectedDate => _selectedDate;
  String get selectedTaxFilter => _selectedTaxFilter;

  // Getters للخصائص الجديدة
  String get dateFilterType => _dateFilterType;
  int? get selectedMonth => _selectedMonth;
  int? get selectedYear => _selectedYear;

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

  // دوال الحصول على القوائم للفلاتر الجديدة
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

  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ دوال الفلترة المتقدمة للتاريخ ██████████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████████████████████████████████████████

  void setDateFilterType(String type) {
    _dateFilterType = type;
    _page = 0;
    _sales.clear();
    notifyListeners();
    fetchSales();
  }

  void setMonthFilter(int month) {
    _selectedMonth = month;
    _dateFilterType = 'month';
    _page = 0;
    _sales.clear();
    notifyListeners();
    fetchSales();
  }

  void setYearFilter(int year) {
    _selectedYear = year;
    _dateFilterType = 'year';
    _page = 0;
    _sales.clear();
    notifyListeners();
    fetchSales();
  }

  void clearDateFilter() {
    _selectedDate = null;
    _selectedMonth = null;
    _selectedYear = null;
    _dateFilterType = 'day';
    _page = 0;
    _sales.clear();
    notifyListeners();
    fetchSales();
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

    // بناء استعلامات الفلترة
    final dateWhereClause = _buildDateWhereClause();

    String paymentWhereClause = '';
    if (_selectedPaymentType != 'الكل') {
      paymentWhereClause = "s.payment_type = '$_selectedPaymentType'";
    }

    String customerWhereClause = '';
    if (_selectedCustomer != 'الكل') {
      if (_selectedCustomer == 'بدون عميل') {
        customerWhereClause = "s.customer_id IS NULL";
      } else {
        customerWhereClause = "c.name = '$_selectedCustomer'";
      }
    }

    String taxWhereClause = '';
    if (_selectedTaxFilter != 'الكل') {
      if (_selectedTaxFilter == 'مضمنه بالضرائب') {
        taxWhereClause = "s.show_for_tax = 1";
      } else if (_selectedTaxFilter == 'غير مضمنه بالضرائب') {
        taxWhereClause = "s.show_for_tax = 0";
      }
    }

    // بناء الجملة WHERE النهائية
    final whereConditions =
        [
              dateWhereClause,
              paymentWhereClause,
              customerWhereClause,
              taxWhereClause,
            ]
            .where((condition) => condition.isNotEmpty && condition != '1=1')
            .toList();

    final whereClause =
        whereConditions.isNotEmpty
            ? 'WHERE ${whereConditions.join(' AND ')}'
            : '';

    final result = await db.rawQuery('''
      SELECT s.*, c.name as customer_name 
      FROM sales s 
      LEFT JOIN customers c ON s.customer_id = c.id 
      $whereClause
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
    _page = 0;
    _sales.clear();
    notifyListeners();
    fetchSales();
  }

  void setCustomerFilter(String? value) {
    _selectedCustomer = value ?? 'الكل';
    _page = 0;
    _sales.clear();
    notifyListeners();
    fetchSales();
  }

  void setDateFilter(DateTime? date) {
    _selectedDate = date;
    _dateFilterType = 'day';
    _page = 0;
    _sales.clear();
    notifyListeners();
    fetchSales();
  }

  void setTaxFilter(String? value) {
    _selectedTaxFilter = value ?? 'الكل';
    _page = 0;
    _sales.clear();
    notifyListeners();
    fetchSales();
  }

  void clearFilters() {
    _selectedPaymentType = 'الكل';
    _selectedCustomer = 'الكل';
    _selectedTaxFilter = 'الكل';
    _page = 0;
    _sales.clear();
    notifyListeners();
    fetchSales();
  }

  void clearAllFilters() {
    _selectedPaymentType = 'الكل';
    _selectedCustomer = 'الكل';
    _selectedTaxFilter = 'الكل';
    _selectedDate = null;
    _selectedMonth = null;
    _selectedYear = null;
    _dateFilterType = 'day';
    _page = 0;
    _sales.clear();
    notifyListeners();
    fetchSales();
  }

  // دالة لإعادة تعيين الحالة
  void reset() {
    _sales.clear();
    _filteredSales.clear();
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
