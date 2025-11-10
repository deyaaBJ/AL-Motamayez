import 'package:flutter/material.dart';
import '../db/db_helper.dart';

class SettingsProvider with ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  // الحد الأدنى للمخزون
  int _lowStockThreshold = 0;
  int get lowStockThreshold => _lowStockThreshold;

  // اسم السوبر ماركت
  String? _marketName;
  String? get marketName => _marketName;

  // 🔹 تحميل جميع الإعدادات من قاعدة البيانات
  Future<void> loadSettings() async {
    try {
      final db = await _dbHelper.db;
      final result = await db.query('settings', limit: 1);

      // جلب القيم
      _lowStockThreshold = result.first['lowStockThreshold'] as int? ?? 0;
      _marketName = result.first['marketName'] as String?;

      notifyListeners();
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  // 🔹 تحديث الحد الأدنى للمخزون
  Future<void> updateLowStockThreshold(int newValue) async {
    try {
      final db = await _dbHelper.db;
      await db.update(
        'settings',
        {'lowStockThreshold': newValue},
        where: 'id = ?',
        whereArgs: [1],
      );
      _lowStockThreshold = newValue;
      notifyListeners();
    } catch (e) {
      print('Error updating lowStockThreshold: $e');
    }
  }

  // 🔹 تحديث اسم السوبر ماركت
  Future<void> updateMarketName(String newName) async {
    try {
      final db = await _dbHelper.db;
      await db.update(
        'settings',
        {'marketName': newName},
        where: 'id = ?',
        whereArgs: [1],
      );
      _marketName = newName;
      notifyListeners();
    } catch (e) {
      print('Error updating marketName: $e');
    }
  }
}
