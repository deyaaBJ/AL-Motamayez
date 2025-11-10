import 'package:flutter/material.dart';
import 'package:shopmate/db/db_helper.dart';
import 'package:shopmate/models/customer.dart';

class CustomerProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();
  List<Customer> _customers = [];

  List<Customer> get customers => _customers;

  // جلب كل الزبائن من الداتا بيس
  Future<void> fetchCustomers() async {
    final db = await _dbHelper.db;
    final result = await db.query('customers', orderBy: 'name ASC');
    _customers = result.map((e) => Customer.fromMap(e)).toList();
    notifyListeners();
  }

  Future<void> searchCustomers(String query) async {
    final db = await _dbHelper.db;

    // إذا البحث فاضي رجع كل الزبائن
    if (query.isEmpty) {
      final result = await db.query('customers', orderBy: 'name ASC');
      _customers = result.map((e) => Customer.fromMap(e)).toList();
    } else {
      final result = await db.query(
        'customers',
        where: 'name LIKE ? OR phone LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'name ASC',
      );
      _customers = result.map((e) => Customer.fromMap(e)).toList();
    }

    notifyListeners();
  }

  // إضافة زبون جديد
  Future<void> addCustomer(Customer customer) async {
    final db = await _dbHelper.db;
    final id = await db.insert('customers', customer.toMap());
    customer.id = id;
    _customers.add(customer);
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
    int index = _customers.indexWhere((c) => c.id == customer.id);
    if (index != -1) {
      _customers[index] = customer;
      notifyListeners();
    }
  }

  // حذف زبون
  Future<void> deleteCustomer(int id) async {
    final db = await _dbHelper.db;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
    _customers.removeWhere((c) => c.id == id);
    notifyListeners();
  }
}
