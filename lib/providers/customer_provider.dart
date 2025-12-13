// providers/customer_provider.dart
import 'package:flutter/material.dart';
import 'package:shopmate/db/db_helper.dart';
import 'package:shopmate/models/customer.dart';

class CustomerProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();
  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  List<Customer> _displayedCustomers = [];
  String _searchQuery = '';

  // متغيرات التحميل التدريجي
  int _currentPage = 0;
  final int _itemsPerPage = 20;
  bool _isLoading = false;
  bool _hasMore = true;

  List<Customer> get customers => _customers;
  List<Customer> get filteredCustomers =>
      _searchQuery.isEmpty ? _customers : _filteredCustomers;
  List<Customer> get displayedCustomers => _displayedCustomers;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  // جلب كل الزبائن من الداتا بيس
  Future<void> fetchCustomers({bool reset = false}) async {
    if (_isLoading) return;

    _isLoading = true;

    if (reset) {
      _currentPage = 0;
      _hasMore = true;
      _customers.clear();
      _displayedCustomers.clear();
    }

    notifyListeners();

    try {
      final db = await _dbHelper.db;

      // التحقق من وجود جدول customers
      final tableInfo = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='customers'",
      );

      if (tableInfo.isEmpty) {
        print('جدول customers غير موجود!');
        _isLoading = false;
        notifyListeners();
        return;
      }

      // حساب OFFSET للتحميل التدريجي
      final offset = _currentPage * _itemsPerPage;

      final result = await db.query(
        'customers',
        orderBy: 'name ASC',
        limit: _itemsPerPage,
        offset: offset,
      );

      print('تم جلب ${result.length} عميل من قاعدة البيانات');

      // إذا كانت النتائج أقل من الحد المطلوب، فهذا يعني لا يوجد المزيد
      if (result.length < _itemsPerPage) {
        _hasMore = false;
      }

      // تحويل البيانات إلى كائنات Customer
      for (var customerData in result) {
        try {
          final customer = Customer.fromMap(customerData);
          print('تم تحويل العميل: ${customer.name} (ID: ${customer.id})');
          _customers.add(customer);
        } catch (e) {
          print('خطأ في تحويل بيانات العميل: $e');
          print('بيانات العميل: $customerData');
        }
      }

      _displayedCustomers = List.from(_customers);
      _filteredCustomers = _displayedCustomers;
      _currentPage++;

      print('إجمالي العملاء المحملين: ${_customers.length}');
    } catch (e) {
      print('خطأ في fetchCustomers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // تحميل المزيد من العملاء
  Future<void> loadMoreCustomers() async {
    if (!_isLoading && _hasMore && _searchQuery.isEmpty) {
      await fetchCustomers();
    }
  }

  // إعادة تحميل من البداية
  Future<void> refreshCustomers() async {
    await fetchCustomers(reset: true);
  }

  Future<void> searchCustomers(String query) async {
    _searchQuery = query;

    if (query.isEmpty) {
      _filteredCustomers = _displayedCustomers;
    } else {
      final results =
          _displayedCustomers.where((customer) {
            final nameMatch = (customer.name ?? '').toLowerCase().contains(
              query.toLowerCase(),
            );
            final phoneMatch = (customer.phone ?? '').toLowerCase().contains(
              query.toLowerCase(),
            );
            return nameMatch || phoneMatch;
          }).toList();

      _filteredCustomers = results;
    }

    notifyListeners();
  }

  // إضافة زبون جديد
  Future<void> addCustomer(Customer customer) async {
    try {
      final db = await _dbHelper.db;
      final id = await db.insert('customers', customer.toMap());

      print('تم إضافة عميل جديد بالـ ID: $id');

      // إنشاء نسخة جديدة من العميل مع ID
      final newCustomer = customer.copyWith(id: id);
      _customers.insert(0, newCustomer); // إضافة في البداية
      _displayedCustomers = List.from(_customers);
      _filteredCustomers = _displayedCustomers;

      // إعادة تعيين التحميل التدريجي
      _currentPage = 0;
      _hasMore = true;

      notifyListeners();
    } catch (e) {
      print('خطأ في addCustomer: $e');
      rethrow;
    }
  }

  // تحديث زبون
  Future<void> updateCustomer(Customer customer) async {
    try {
      final db = await _dbHelper.db;
      await db.update(
        'customers',
        customer.toMap(),
        where: 'id = ?',
        whereArgs: [customer.id],
      );

      // تحديث في القائمة المحلية
      final index = _customers.indexWhere((c) => c.id == customer.id);
      if (index != -1) {
        _customers[index] = customer;
        _displayedCustomers = List.from(_customers);
        _filteredCustomers = _displayedCustomers;
        notifyListeners();
      }
    } catch (e) {
      print('خطأ في updateCustomer: $e');
      rethrow;
    }
  }

  // حذف زبون
  Future<void> deleteCustomer(int id) async {
    try {
      final db = await _dbHelper.db;

      // التحقق مما إذا كان للعميل فواتير مرتبطة
      final sales = await db.query(
        'sales',
        where: 'customer_id = ?',
        whereArgs: [id],
      );

      if (sales.isNotEmpty) {
        throw Exception('لا يمكن حذف العميل لأنه لديه فواتير مرتبطة');
      }

      await db.delete('customers', where: 'id = ?', whereArgs: [id]);

      // حذف من القائمة المحلية
      _customers.removeWhere((c) => c.id == id);
      _displayedCustomers = List.from(_customers);
      _filteredCustomers = _displayedCustomers;

      notifyListeners();
    } catch (e) {
      print('خطأ في deleteCustomer: $e');
      rethrow;
    }
  }

  // الحصول على فواتير العميل
  Future<List<Map<String, dynamic>>> getCustomerSales(int customerId) async {
    try {
      final db = await _dbHelper.db;

      final List<Map<String, dynamic>> sales = await db.query(
        'sales',
        where: 'customer_id = ?',
        whereArgs: [customerId],
        orderBy: 'date DESC',
      );

      return sales;
    } catch (e) {
      print('خطأ في getCustomerSales: $e');
      return [];
    }
  }

  // الحصول على إجمالي المشتريات للعميل
  Future<double> getCustomerTotalPurchases(int customerId) async {
    try {
      final db = await _dbHelper.db;

      final result = await db.rawQuery(
        'SELECT SUM(total_amount) as total FROM sales WHERE customer_id = ? AND total_amount > 0',
        [customerId],
      );

      if (result.isEmpty || result.first['total'] == null) {
        return 0.0;
      }

      return _safeToDouble(result.first['total']);
    } catch (e) {
      print('خطأ في getCustomerTotalPurchases: $e');
      return 0.0;
    }
  }

  // الحصول على تفاصيل العميل مع إحصائياته
  Future<Map<String, dynamic>> getCustomerDetails(int customerId) async {
    try {
      final customer = _customers.firstWhere((c) => c.id == customerId);
      final sales = await getCustomerSales(customerId);
      final totalPurchases = await getCustomerTotalPurchases(customerId);

      return {
        'customer': customer,
        'sales': sales,
        'totalPurchases': totalPurchases,
        'salesCount': sales.length,
      };
    } catch (e) {
      print('خطأ في getCustomerDetails: $e');
      return {
        'customer': null,
        'sales': [],
        'totalPurchases': 0.0,
        'salesCount': 0,
      };
    }
  }

  // الحصول على عميل بواسطة الـ ID
  Customer? getCustomerById(int id) {
    try {
      return _customers.firstWhere((customer) => customer.id == id);
    } catch (e) {
      return null;
    }
  }

  // مسح البحث
  void clearSearch() {
    _searchQuery = '';
    _filteredCustomers = _displayedCustomers;
    notifyListeners();
  }

  // دالة مساعدة للتحويل الآمن إلى double
  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  void dispose() {
    super.dispose();
  }
}
