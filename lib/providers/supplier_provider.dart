import 'package:flutter/material.dart';
import '../db/db_helper.dart';

class SupplierProvider with ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> get suppliers => _suppliers;

  // تحميل كل الموردين
  Future<void> loadSuppliers() async {
    final db = await _dbHelper.db;
    _suppliers = await db.query('suppliers', orderBy: 'name ASC');
    notifyListeners();
  }

  // إضافة مورد
  Future<void> addSupplier({required String name, String? phone}) async {
    final db = await _dbHelper.db;

    await db.insert('suppliers', {'name': name, 'phone': phone});

    await loadSuppliers();
  }

  // حذف مورد
  Future<void> deleteSupplier(int supplierId) async {
    final db = await _dbHelper.db;

    await db.delete('suppliers', where: 'id = ?', whereArgs: [supplierId]);

    await loadSuppliers();
  }
}
