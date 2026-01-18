import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:motamayez/db/db_helper.dart';
import 'package:motamayez/models/customer.dart';

class CustomerProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();
  final List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  String _searchQuery = '';

  // متغيرات التحميل التدريجي
  int _currentPage = 0;
  final int _itemsPerPage = 20;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isSearching = false;

  List<Customer> get customers => _customers;
  List<Customer> get filteredCustomers => _filteredCustomers;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  bool get isSearching => _isSearching;

  // جلب الزبائن بشكل تدريجي - دالة واحدة لكل شيء
  Future<void> fetchCustomers({bool reset = false}) async {
    if (_isLoading) return;

    _isLoading = true;

    try {
      final db = await _dbHelper.db;

      if (reset) {
        _currentPage = 0;
        _hasMore = true;
        if (_isSearching) {
          _filteredCustomers.clear();
        } else {
          _customers.clear();
        }
      }

      final offset = _currentPage * _itemsPerPage;
      List<Map<String, dynamic>> result;

      if (_isSearching && _searchQuery.isNotEmpty) {
        // البحث في الاسم فقط مع pagination
        result = await db.rawQuery(
          '''
          SELECT * FROM customers 
          WHERE name LIKE ?
          ORDER BY name ASC
          LIMIT ? OFFSET ?
          ''',
          ['%$_searchQuery%', _itemsPerPage, offset],
        );
        log(
          '🔍 بحث: "$_searchQuery"، الصفحة: $_currentPage، النتائج: ${result.length}',
        );
      } else {
        // التحميل العادي مع pagination
        result = await db.query(
          'customers',
          orderBy: 'name ASC',
          limit: _itemsPerPage,
          offset: offset,
        );
        log('📊 تحميل عادي، الصفحة: $_currentPage، النتائج: ${result.length}');
      }

      // ✅ تحديث _hasMore بناءً على عدد النتائج الفعلي
      _hasMore = result.length == _itemsPerPage;
      log(
        '✅ _hasMore: $_hasMore (نتائج: ${result.length}, itemsPerPage: $_itemsPerPage)',
      );

      for (var customerData in result) {
        try {
          final customer = Customer.fromMap(customerData);

          if (_isSearching) {
            // للبحث: أضف فقط إذا لم يكن موجوداً
            if (!_filteredCustomers.any((c) => c.id == customer.id)) {
              _filteredCustomers.add(customer);
            }
          } else {
            // للتحميل العادي: أضف فقط إذا لم يكن موجوداً
            if (!_customers.any((c) => c.id == customer.id)) {
              _customers.add(customer);
            }
          }
        } catch (e) {
          log('خطأ في تحويل بيانات العميل: $e');
        }
      }

      // ✅ زيادة الصفحة فقط إذا لم يكن reset وكانت هناك نتائج
      if (!reset && result.isNotEmpty) {
        _currentPage++;
        log('📈 زيادة الصفحة إلى: $_currentPage');
      }
    } catch (e) {
      log('خطأ في fetchCustomers: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // الحصول على العملاء للعرض (بناءً على حالة البحث)
  List<Customer> get displayedCustomers {
    return _isSearching ? _filteredCustomers : _customers;
  }

  // في CustomerProvider، أضف هذه الدالة بعد fetchCustomers:
  Future<bool> isCustomerNameExists(String name, {int? excludeId}) async {
    try {
      final db = await _dbHelper.db;

      if (excludeId != null) {
        // للتحقق عند التعديل (استبعاد العميل الحالي)
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM customers WHERE name = ? AND id != ?',
          [name, excludeId],
        );
        final count = result.first['count'] as int;
        return count > 0;
      } else {
        // للتحقق عند الإضافة
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM customers WHERE name = ?',
          [name],
        );
        final count = result.first['count'] as int;
        return count > 0;
      }
    } catch (e) {
      log('خطأ في التحقق من وجود الاسم: $e');
      return false;
    }
  }

  // ثم عدل دالة addCustomer لتحتوي على التحقق:
  Future<Customer> addCustomer(Customer customer) async {
    try {
      // التحقق من وجود عميل بنفس الاسم
      final nameExists = await isCustomerNameExists(customer.name);
      if (nameExists) {
        throw Exception('اسم العميل "${customer.name}" موجود مسبقاً');
      }

      final db = await _dbHelper.db;
      final id = await db.insert('customers', customer.toMap());

      final newCustomer = customer.copyWith(id: id);

      // إضافة في البداية من القوائم
      _customers.insert(0, newCustomer);

      // إذا كان البحث نشطًا والعميل الجديد يتطابق مع البحث، أضفه للنتائج
      if (_isSearching && _searchQuery.isNotEmpty) {
        final lowerQuery = _searchQuery.toLowerCase();
        final nameMatch = newCustomer.name.toLowerCase().contains(lowerQuery);

        if (nameMatch) {
          _filteredCustomers.insert(0, newCustomer);
        }
      }

      // تحديث حالة _hasMore
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM customers',
      );
      final totalCount = countResult.first['count'] as int;
      _hasMore = _customers.length < totalCount;

      log(
        '✅ تم إضافة عميل جديد. الإجمالي: $totalCount, المحملين: ${_customers.length}, _hasMore: $_hasMore',
      );

      notifyListeners();
      return newCustomer;
    } catch (e) {
      log('خطأ في addCustomer: $e');
      rethrow;
    }
  }

  // وأيضاً عدل دالة updateCustomer للتحقق عند التعديل:
  Future<void> updateCustomer(Customer customer) async {
    try {
      // التحقق من وجود عميل آخر بنفس الاسم (غير العميل الحالي)
      final nameExists = await isCustomerNameExists(
        customer.name,
        excludeId: customer.id,
      );
      if (nameExists) {
        throw Exception('اسم العميل "${customer.name}" موجود مسبقاً');
      }

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

        // إذا كان البحث نشطًا، تحديث النتائج أيضًا
        if (_isSearching) {
          final searchIndex = _filteredCustomers.indexWhere(
            (c) => c.id == customer.id,
          );
          if (searchIndex != -1) {
            _filteredCustomers[searchIndex] = customer;
          } else {
            // إذا كان الاسم يتطابق مع البحث، أضفه للنتائج
            final lowerQuery = _searchQuery.toLowerCase();
            if (customer.name.toLowerCase().contains(lowerQuery)) {
              _filteredCustomers.insert(0, customer);
            }
          }
        }

        notifyListeners();
      }
    } catch (e) {
      log('خطأ في updateCustomer: $e');
      rethrow;
    }
  }

  // 🔄 إضافة عميل جديد

  // 🔍 البحث في العملاء
  Future<void> searchCustomers(String query) async {
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      cancelSearch();
      return;
    }

    _searchQuery = trimmedQuery;
    _isSearching = true;

    log('🔍 بدء البحث عن: "$_searchQuery"');

    // جلب أول 20 نتيجة بحث فقط
    await fetchCustomers(reset: true);

    log(
      '✅ بحث مكتمل. عدد النتائج: ${_filteredCustomers.length}, _hasMore: $_hasMore',
    );
  }

  // ❌ إلغاء البحث
  void cancelSearch() {
    _searchQuery = '';
    _isSearching = false;
    _filteredCustomers.clear();
    _currentPage = 0;
    _hasMore = true;

    log('❌ تم إلغاء البحث');
    notifyListeners();
  }

  // 📥 تحميل المزيد من العملاء (يعمل مع البحث والتحميل العادي)
  Future<void> loadMoreCustomers() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      final db = await _dbHelper.db;
      final offset = _customers.length;

      List<Map<String, dynamic>> result;

      if (_isSearching && _searchQuery.isNotEmpty) {
        result = await db.rawQuery(
          '''
        SELECT * FROM customers 
        WHERE name LIKE ?
        ORDER BY name ASC
        LIMIT ? OFFSET ?
        ''',
          ['%$_searchQuery%', _itemsPerPage, offset],
        );
      } else {
        result = await db.query(
          'customers',
          orderBy: 'name ASC',
          limit: _itemsPerPage,
          offset: offset,
        );
      }

      for (var customerData in result) {
        try {
          final customer = Customer.fromMap(customerData);
          if (!_customers.any((c) => c.id == customer.id)) {
            _customers.add(customer);
          }
          if (_isSearching &&
              !_filteredCustomers.any((c) => c.id == customer.id)) {
            _filteredCustomers.add(customer);
          }
        } catch (e) {
          log('خطأ في تحويل بيانات العميل: $e');
        }
      }

      _hasMore = result.length == _itemsPerPage;
    } catch (e) {
      log('خطأ في loadMoreCustomers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 🔄 تحديث جميع البيانات
  Future<void> refreshCustomers() async {
    log('🔄 تحديث جميع البيانات');
    await fetchCustomers(reset: true);
  }

  // ✏️ تحديث زبون

  // 🗑️ حذف زبون
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
      _filteredCustomers.removeWhere((c) => c.id == id);

      // تحديث _hasMore
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM customers',
      );
      final totalCount = countResult.first['count'] as int;
      _hasMore = _customers.length < totalCount;

      notifyListeners();
    } catch (e) {
      log('خطأ في deleteCustomer: $e');
      rethrow;
    }
  }

  // 📊 دالة خاصة للبحث في جميع البيانات (للاستخدام في أماكن أخرى)
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
      log('خطأ في searchInDatabase: $e');
      return [];
    }
  }

  // 🔢 الحصول على إجمالي عدد العملاء في قاعدة البيانات
  Future<int> getTotalCustomersCount() async {
    try {
      final db = await _dbHelper.db;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM customers',
      );
      return result.first['count'] as int;
    } catch (e) {
      log('خطأ في getTotalCustomersCount: $e');
      return 0;
    }
  }

  // 👤 الحصول على عميل بالـ ID
  Customer? getCustomerById(int id) {
    try {
      return _customers.firstWhere((customer) => customer.id == id);
    } catch (e) {
      return null;
    }
  }

  // 🧹 تنظيف البحث (بدون إلغاء)
  void clearSearch() {
    _searchQuery = '';
    _isSearching = false;
    _filteredCustomers = List.from(_customers);
    notifyListeners();
  }

  // باقي الدوال المساعدة
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
      log('خطأ في getCustomerSales: $e');
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
      log('خطأ في getCustomerTotalPurchases: $e');
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
      log('خطأ في getCustomerDetails: $e');
      return {
        'customer': null,
        'sales': [],
        'totalPurchases': 0.0,
        'salesCount': 0,
      };
    }
  }

  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
