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

  // جلب كل الزبائن من الداتا بيس مع حساب الدين والنقدي
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

    final db = await _dbHelper.db;

    // حساب OFFSET للتحميل التدريجي
    final offset = _currentPage * _itemsPerPage;

    final result = await db.query(
      'customers',
      orderBy: 'name ASC',
      limit: _itemsPerPage,
      offset: offset,
    );

    // إذا كانت النتائج أقل من الحد المطلوب، فهذا يعني لا يوجد المزيد
    if (result.length < _itemsPerPage) {
      _hasMore = false;
    }

    for (var customerData in result) {
      final customer = Customer.fromMap(customerData);

      // حساب الدين والنقدي للعميل من الفواتير
      final totals = await _calculateCustomerTotals(customer.id!);

      final updatedCustomer = customer.copyWith(
        debt: totals['debt'] ?? 0.0,
        totalCash: totals['cash'] ?? 0.0,
      );

      _customers.add(updatedCustomer);
    }

    _displayedCustomers = List.from(_customers);
    _filteredCustomers = _displayedCustomers;
    _currentPage++;
    _isLoading = false;

    notifyListeners();
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

  // حساب إجمالي الدين والنقدي للعميل من الفواتير
  Future<Map<String, double>> _calculateCustomerTotals(int customerId) async {
    final db = await _dbHelper.db;

    // جلب جميع فواتير العميل
    final List<Map<String, dynamic>> sales = await db.query(
      'sales',
      where: 'customer_id = ?',
      whereArgs: [customerId],
    );

    double totalDebt = 0.0;
    double totalCash = 0.0;

    for (var sale in sales) {
      final paymentType = sale['payment_type'] as String? ?? 'cash';
      final totalAmount = _safeToDouble(sale['total_amount']);

      if (paymentType == 'credit') {
        totalDebt += totalAmount;
      } else if (paymentType == 'cash') {
        totalCash += totalAmount;
      }
    }

    return {'debt': totalDebt, 'cash': totalCash};
  }

  // دالة مساعدة للتحويل الآمن إلى double
  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> searchCustomers(String query) async {
    _searchQuery = query;

    if (query.isEmpty) {
      _filteredCustomers = _displayedCustomers;
    } else {
      final results =
          _displayedCustomers.where((customer) {
            final nameMatch = customer.name.toLowerCase().contains(
              query.toLowerCase(),
            );
            final phoneMatch =
                customer.phone?.toLowerCase().contains(query.toLowerCase()) ??
                false;
            return nameMatch || phoneMatch;
          }).toList();

      _filteredCustomers = results;
    }

    notifyListeners();
  }

  // إضافة زبون جديد
  Future<void> addCustomer(Customer customer) async {
    final db = await _dbHelper.db;
    final id = await db.insert('customers', customer.toMap());

    // إنشاء نسخة جديدة من العميل مع ID
    final newCustomer = customer.copyWith(id: id);
    _customers.insert(0, newCustomer); // إضافة في البداية
    _displayedCustomers = List.from(_customers);
    _filteredCustomers = _displayedCustomers;

    // إعادة تعيين التحميل التدريجي
    _currentPage = 0;
    _hasMore = true;

    notifyListeners();
  }

  // تحديث زبون
  Future<void> updateCustomer(Customer customer) async {
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
  }

  // حذف زبون
  Future<void> deleteCustomer(int id) async {
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
  }

  // تسديد دين العميل
  Future<void> payDebt(
    int customerId,
    double amount,
    String paymentType,
  ) async {
    if (amount <= 0) {
      throw Exception('المبلغ يجب أن يكون أكبر من الصفر');
    }

    final db = await _dbHelper.db;

    // البحث عن العميل
    final customerIndex = _customers.indexWhere((c) => c.id == customerId);
    if (customerIndex == -1) {
      throw Exception('العميل غير موجود');
    }

    final customer = _customers[customerIndex];

    if (amount > customer.debt) {
      throw Exception('المبلغ المسدد أكبر من الدين المتبقي');
    }

    // إضافة فاتورة دفع (فاتورة بسالب للمبلغ)
    await db.insert('sales', {
      'date': DateTime.now().toIso8601String(),
      'total_amount': -amount, // سالب لأنها دفعة
      'total_profit': 0.0,
      'customer_id': customerId,
      'payment_type': paymentType,
      'show_for_tax': 0,
    });

    // تحديث الدين المحلي
    final updatedCustomer = customer.copyWith(debt: customer.debt - amount);
    _customers[customerIndex] = updatedCustomer;
    _displayedCustomers = List.from(_customers);
    _filteredCustomers = _displayedCustomers;

    notifyListeners();
  }

  // الحصول على إحصائيات العملاء (من العملاء المحملين فقط)
  Map<String, dynamic> getCustomerStats() {
    final totalCustomers = _customers.length;
    final totalDebt = _customers.fold(
      0.0,
      (sum, customer) => sum + customer.debt,
    );
    final totalCash = _customers.fold(
      0.0,
      (sum, customer) => sum + customer.totalCash,
    );
    final customersWithDebt = _customers.where((c) => c.debt > 0).length;
    final totalPurchases = totalDebt + totalCash;

    return {
      'totalCustomers': totalCustomers,
      'totalDebt': totalDebt,
      'totalCash': totalCash,
      'totalPurchases': totalPurchases,
      'customersWithDebt': customersWithDebt,
    };
  }

  // الحصول على فواتير العميل
  Future<List<Map<String, dynamic>>> getCustomerSales(int customerId) async {
    final db = await _dbHelper.db;

    final List<Map<String, dynamic>> sales = await db.query(
      'sales',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'date DESC',
    );

    return sales;
  }

  // الحصول على إجمالي المشتريات للعميل
  Future<double> getCustomerTotalPurchases(int customerId) async {
    final db = await _dbHelper.db;

    final result = await db.rawQuery(
      'SELECT SUM(total_amount) as total FROM sales WHERE customer_id = ? AND total_amount > 0',
      [customerId],
    );

    return _safeToDouble(result.first['total']);
  }

  // تحديث الدين يدوياً (للتعديلات الطارئة)
  Future<void> updateCustomerDebt(int customerId, double newDebt) async {
    final customer = _customers.firstWhere((c) => c.id == customerId);
    final currentDebt = customer.debt;
    final difference = newDebt - currentDebt;

    if (difference != 0) {
      final db = await _dbHelper.db;

      // إضافة فاتورة ضبط للفرق
      await db.insert('sales', {
        'date': DateTime.now().toIso8601String(),
        'total_amount': difference,
        'total_profit': 0.0,
        'customer_id': customerId,
        'payment_type': 'credit',
        'show_for_tax': 0,
      });

      await fetchCustomers();
    }
  }

  // إضافة فاتورة وتحديث الدين تلقائياً
  Future<void> addSaleForCustomer(
    int customerId,
    double amount,
    String paymentType,
  ) async {
    final db = await _dbHelper.db;

    // إضافة الفاتورة
    await db.insert('sales', {
      'date': DateTime.now().toIso8601String(),
      'total_amount': amount,
      'total_profit': 0.0, // يمكن حساب الربح لاحقاً
      'customer_id': customerId,
      'payment_type': paymentType,
      'show_for_tax': 0,
    });

    // إعادة تحميل العملاء لتحديث الأرقام
    await fetchCustomers();
  }

  // الحصول على تفاصيل العميل مع إحصائياته
  Future<Map<String, dynamic>> getCustomerDetails(int customerId) async {
    final customer = _customers.firstWhere((c) => c.id == customerId);
    final sales = await getCustomerSales(customerId);
    final totalPurchases = await getCustomerTotalPurchases(customerId);

    return {
      'customer': customer,
      'sales': sales,
      'totalPurchases': totalPurchases,
      'salesCount': sales.length,
    };
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

  @override
  void dispose() {
    super.dispose();
  }
}
