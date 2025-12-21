// providers/customer_provider.dart - النسخة المعدلة
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
  bool _isSearching = false;

  List<Customer> get customers => _customers;
  List<Customer> get filteredCustomers =>
      _searchQuery.isEmpty ? _customers : _filteredCustomers;
  List<Customer> get displayedCustomers => _displayedCustomers;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  bool get isSearching => _isSearching;

  // جلب الزبائن بشكل تدريجي
  Future<void> fetchCustomers({
    bool reset = false,
    bool isSearch = false,
  }) async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final db = await _dbHelper.db;

      if (reset) {
        _currentPage = 0;
        _hasMore = true;
        if (!isSearch) {
          _customers.clear();
          _displayedCustomers.clear();
          _filteredCustomers.clear();
        }
      }

      final offset = _currentPage * _itemsPerPage;
      List<Map<String, dynamic>> result;

      if (_searchQuery.isNotEmpty && !isSearch) {
        // البحث في قاعدة البيانات
        result = await db.rawQuery(
          '''
          SELECT * FROM customers 
          WHERE name LIKE ? OR phone LIKE ?
          ORDER BY name ASC
          LIMIT ? OFFSET ?
        ''',
          ['%$_searchQuery%', '%$_searchQuery%', _itemsPerPage, offset],
        );
      } else {
        // التحميل العادي
        result = await db.query(
          'customers',
          orderBy: 'name ASC',
          limit: _itemsPerPage,
          offset: offset,
        );
      }

      print('تم جلب ${result.length} عميل (الصفحة $_currentPage)');

      if (result.length < _itemsPerPage) {
        _hasMore = false;
      }

      final existingIds = _customers.map((c) => c.id).toSet();

      for (var customerData in result) {
        try {
          final customer = Customer.fromMap(customerData);
          if (!existingIds.contains(customer.id)) {
            if (isSearch) {
              _filteredCustomers.add(customer);
            } else {
              _customers.add(customer);
            }
            existingIds.add(customer.id);
          }
        } catch (e) {
          print('خطأ في تحويل بيانات العميل: $e');
        }
      }

      if (isSearch) {
        _displayedCustomers = List.from(_filteredCustomers);
      } else {
        _displayedCustomers = List.from(_customers);
        if (_searchQuery.isNotEmpty) {
          await _applyLocalSearch(_searchQuery);
        }
      }

      if (!isSearch) {
        _currentPage++;
      }

      print('إجمالي العملاء المحملين: ${_customers.length}');
    } catch (e) {
      print('خطأ في fetchCustomers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void resetCustomers() {
    _currentPage = 0;
    _hasMore = true;
    _customers.clear();
    _displayedCustomers.clear();
    _filteredCustomers.clear();
    _searchQuery = '';
    _isSearching = false;
    notifyListeners();
  }

  // تحميل المزيد من العملاء
  Future<void> loadMoreCustomers() async {
    if (!_isLoading && _hasMore) {
      await fetchCustomers();
    }
  }

  // البحث في قاعدة البيانات
  Future<void> searchCustomers(String query) async {
    _searchQuery = query;

    if (query.isEmpty) {
      // إذا كان البحث فارغاً، ارجع للبيانات المحملة
      _isSearching = false;
      _filteredCustomers = List.from(_customers);
      _displayedCustomers = List.from(_customers);
      notifyListeners();
      return;
    }

    _isSearching = true;
    _filteredCustomers.clear();
    _currentPage = 0;
    _hasMore = true;

    // البحث في قاعدة البيانات
    while (_hasMore && _isSearching) {
      await fetchCustomers(reset: _currentPage == 0, isSearch: true);
    }
  }

  // البحث المحلي في البيانات المحملة (للاستخدام السريع)
  Future<void> _applyLocalSearch(String query) async {
    if (query.isEmpty) {
      _filteredCustomers = List.from(_customers);
      _displayedCustomers = List.from(_customers);
      return;
    }

    final lowerQuery = query.toLowerCase();
    _filteredCustomers =
        _customers.where((customer) {
          final nameMatch = (customer.name ?? '').toLowerCase().contains(
            lowerQuery,
          );
          final phoneMatch = (customer.phone ?? '').toLowerCase().contains(
            lowerQuery,
          );
          return nameMatch || phoneMatch;
        }).toList();

    _displayedCustomers = List.from(_filteredCustomers);
  }

  // إضافة زبون جديد مع التحديث
  Future<int> addCustomer(Customer customer) async {
    try {
      final db = await _dbHelper.db;
      final id = await db.insert('customers', customer.toMap());

      final newCustomer = customer.copyWith(id: id);

      // إضافة في البداية من القوائم
      _customers.insert(0, newCustomer);

      if (_searchQuery.isNotEmpty) {
        // تطبيق البحث على العميل الجديد
        final lowerQuery = _searchQuery.toLowerCase();
        final nameMatch = newCustomer.name.toLowerCase().contains(lowerQuery);
        final phoneMatch =
            newCustomer.phone?.toLowerCase().contains(lowerQuery) ?? false;

        if (nameMatch || phoneMatch) {
          _filteredCustomers.insert(0, newCustomer);
          _displayedCustomers = List.from(_filteredCustomers);
        }
      } else {
        _filteredCustomers.insert(0, newCustomer);
        _displayedCustomers = List.from(_customers);
      }

      // إعادة تعيين التحميل التدريجي
      _currentPage = 0;
      _hasMore = true;

      notifyListeners();

      print('تم إضافة عميل جديد بالـ ID: $id');
      return id;
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

        if (_searchQuery.isNotEmpty) {
          await _applyLocalSearch(_searchQuery);
        } else {
          _displayedCustomers = List.from(_customers);
          _filteredCustomers = List.from(_customers);
        }

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

      // حذف من القوائم المحلية
      _customers.removeWhere((c) => c.id == id);

      if (_searchQuery.isNotEmpty) {
        await _applyLocalSearch(_searchQuery);
      } else {
        _displayedCustomers = List.from(_customers);
        _filteredCustomers = List.from(_customers);
      }

      notifyListeners();
    } catch (e) {
      print('خطأ في deleteCustomer: $e');
      rethrow;
    }
  }

  // إعادة تحميل من البداية
  Future<void> refreshCustomers() async {
    await fetchCustomers(reset: true);
  }

  // دالة خاصة للبحث في جميع البيانات (مستقلة عن البيانات المحملة)
  Future<List<Customer>> searchInDatabase(String query) async {
    try {
      final db = await _dbHelper.db;

      final result = await db.rawQuery(
        '''
        SELECT * FROM customers 
        WHERE name LIKE ? OR phone LIKE ?
        ORDER BY name ASC
      ''',
        ['%$query%', '%$query%'],
      );

      return result.map((map) => Customer.fromMap(map)).toList();
    } catch (e) {
      print('خطأ في searchInDatabase: $e');
      return [];
    }
  }

  // الحصول على إجمالي عدد العملاء في قاعدة البيانات
  Future<int> getTotalCustomersCount() async {
    try {
      final db = await _dbHelper.db;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM customers',
      );
      return result.first['count'] as int;
    } catch (e) {
      print('خطأ في getTotalCustomersCount: $e');
      return 0;
    }
  }

  // إلغاء البحث والعودة للبيانات المحملة
  void cancelSearch() {
    _searchQuery = '';
    _isSearching = false;
    _filteredCustomers = List.from(_customers);
    _displayedCustomers = List.from(_customers);
    notifyListeners();
  }

  // باقي الدوال تبقى كما هي...
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

  Customer? getCustomerById(int id) {
    try {
      return _customers.firstWhere((customer) => customer.id == id);
    } catch (e) {
      return null;
    }
  }

  void clearSearch() {
    _searchQuery = '';
    _isSearching = false;
    _filteredCustomers = _displayedCustomers;
    notifyListeners();
  }

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
