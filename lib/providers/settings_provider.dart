import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import 'dart:developer';

class SettingsProvider with ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  // الحد الأدنى للمخزون
  int _lowStockThreshold = 0;
  int get lowStockThreshold => _lowStockThreshold;

  // الإعداد الضريبي
  int _defaultTaxSetting = 0;
  int get defaultTaxSetting => _defaultTaxSetting;

  // اسم السوبر ماركت
  String? _marketName;
  String? get marketName => _marketName;

  // 🔹 العملة
  String? _currency;
  String? get currency => _currency;

  //printerPort
  int? _printerPort;
  int? get printerPort => _printerPort;

  //printerIp
  String? _printerIp;
  String? get printerIp => _printerIp;

  //size
  String? _paperSize;
  String? get paperSize => _paperSize;

  //numberOfCopies
  int? _numberOfCopies;
  int? get numberOfCopies => _numberOfCopies;

  // 🔹 تحميل جميع الإعدادات من قاعدة البيانات
  Future<void> loadSettings() async {
    try {
      final db = await _dbHelper.db;
      final result = await db.query('settings', limit: 1);

      if (result.isNotEmpty) {
        _lowStockThreshold = _parseInt(result.first['lowStockThreshold']) ?? 0;

        _marketName = result.first['marketName'] as String?;

        dynamic taxSetting = result.first['defaultTaxSetting'];
        if (taxSetting is String) {
          _defaultTaxSetting = int.tryParse(taxSetting) ?? 0;
        } else if (taxSetting is int) {
          _defaultTaxSetting = taxSetting;
        }

        // 🔹 تحميل العملة
        _currency = result.first['currency'] as String? ?? 'USD';
        // تحميل printerPort
        dynamic port = result.first['printerPort'];
        _printerPort = port;
        // تحميل printerIp
        _printerIp = result.first['printerIp'] as String?;
        // تحميل paperSize
        _paperSize = result.first['paperSize'] as String? ?? '58mm';
        // تحميل numberOfCopies
        _numberOfCopies = _parseInt(result.first['numberOfCopies']) ?? 1;
      }

      notifyListeners();
    } catch (e) {
      log('Error loading settings: $e');
    }
  }

  // دالة مساعدة
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
      log('Error updating lowStockThreshold: $e');
    }
  }

  // 🔹 تحديث الإعداد الضريبي
  Future<void> updateDefaultTaxSetting(int newValue) async {
    try {
      final db = await _dbHelper.db;
      await db.update(
        'settings',
        {'defaultTaxSetting': newValue},
        where: 'id = ?',
        whereArgs: [1],
      );
      _defaultTaxSetting = newValue;
      notifyListeners();
    } catch (e) {
      log('Error updating defaultTaxSetting: $e');
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
      log('Error updating marketName: $e');
    }
  }

  // 🔹 تحديث العملة
  String get currencyName {
    switch (_currency) {
      case 'USD':
        return 'دولار';
      case 'JOD':
        return 'دينار';
      case 'ILS':
        return 'شيكل';
      default:
        return 'دولار';
    }
  }

  // 🔹 تحديث العملة
  Future<void> updateCurrency(String newCurrency) async {
    final db = await _dbHelper.db;
    await db.update(
      'settings',
      {'currency': newCurrency},
      where: 'id = ?',
      whereArgs: [1],
    );
    _currency = newCurrency;
    notifyListeners();
  }

  //updatePrinterSettings تحديث
  Future<void> updatePrinterSettings({
    required String ip,
    required int port,
    required String size,
  }) async {
    try {
      final db = await _dbHelper.db;
      await db.update(
        'settings',
        {'printerIp': ip, 'printerPort': port, 'paperSize': size},
        where: 'id = ?',
        whereArgs: [1],
      );
      _printerIp = ip;
      _printerPort = port;
      _paperSize = size;
      notifyListeners();
    } catch (e) {
      log('Error updating printer settings: $e');
    }
  }

  // في class SettingsProvider
  Future<void> updatePaperSize(String newSize) async {
    try {
      final db = await _dbHelper.db;
      await db.update(
        'settings',
        {'paperSize': newSize},
        where: 'id = ?',
        whereArgs: [1],
      );
      _paperSize = newSize;
      notifyListeners();
    } catch (e) {
      log('Error updating paperSize: $e');
    }
  }

  //_numberOfCopies تحديث
  Future<void> updateNumberOfCopies(int newCopies) async {
    try {
      final db = await _dbHelper.db;
      await db.update(
        'settings',
        {'numberOfCopies': newCopies},
        where: 'id = ?',
        whereArgs: [1],
      );
      _numberOfCopies = newCopies;
      notifyListeners();
    } catch (e) {
      log('Error updating numberOfCopies: $e');
    }
  }
}
