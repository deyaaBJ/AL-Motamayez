import 'package:flutter/material.dart';
import '../db/db_helper.dart';

class SettingsProvider with ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  // الحد الأدنى للمخزون
  int _lowStockThreshold = 0;
  int get lowStockThreshold => _lowStockThreshold;

  // الإعداد الضريبي - استخدم _ مع getter
  int _defaultTaxSetting = 0;
  int get defaultTaxSetting => _defaultTaxSetting;

  // اسم السوبر ماركت
  String? _marketName;
  String? get marketName => _marketName;

  // 🔹 تحميل جميع الإعدادات من قاعدة البيانات
  // 🔹 تحميل جميع الإعدادات من قاعدة البيانات
  Future<void> loadSettings() async {
    try {
      final db = await _dbHelper.db;
      final result = await db.query('settings', limit: 1);

      if (result.isNotEmpty) {
        // جلب القيم مع معالجة أنواع البيانات
        _lowStockThreshold = _parseInt(result.first['lowStockThreshold']) ?? 0;
        _marketName = result.first['marketName'] as String?;

        // معالجة خاصية الضريبة - قد تكون String أو int
        dynamic taxSetting = result.first['defaultTaxSetting'];
        if (taxSetting is String) {
          _defaultTaxSetting = int.tryParse(taxSetting) ?? 0;
        } else if (taxSetting is int) {
          _defaultTaxSetting = taxSetting;
        } else {
          _defaultTaxSetting = 0;
        }

        print('🔄 تم تحميل الإعدادات:');
        print('   - lowStockThreshold: $_lowStockThreshold');
        print('   - marketName: $_marketName');
        print(
          '   - defaultTaxSetting: $_defaultTaxSetting (type: ${taxSetting.runtimeType})',
        );
      }

      notifyListeners();
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  // 🔹 دالة مساعدة لتحويل القيم إلى int
  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
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

  // 🔹 تحديث الإعداد الضريبي الافتراضي
  Future<void> updateDefaultTaxSetting(int newValue) async {
    try {
      final db = await _dbHelper.db;
      int rowsUpdated = await db.update(
        'settings',
        {'defaultTaxSetting': newValue},
        where: 'id = ?',
        whereArgs: [1],
      );

      print('📊 عدد الصفوف المحدثة في DB: $rowsUpdated');

      // هذا هو التصحيح المهم - استخدم _defaultTaxSetting
      _defaultTaxSetting = newValue;
      notifyListeners();

      print('✅ تم تحديث الإعداد الضريبي بنجاح إلى: $newValue');
      print('🔍 القيمة بعد التحديث في البروفايدر: $_defaultTaxSetting');

      // تحقق من القيمة في DB مباشرة
      final verify = await db.query('settings', limit: 1);
      if (verify.isNotEmpty) {
        int dbValue = verify.first['defaultTaxSetting'] as int? ?? -1;
        print('🔍 القيمة في قاعدة البيانات: $dbValue');
      }
    } catch (e) {
      print('❌ خطأ في تحديث الإعداد الضريبي: $e');
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

  // 🔹 دالة للمساعدة في التصحيح
  void printCurrentState() {
    print('🔄 الحالة الحالية:');
    print('   - _lowStockThreshold: $_lowStockThreshold');
    print('   - _defaultTaxSetting: $_defaultTaxSetting');
    print('   - _marketName: $_marketName');
  }
}
