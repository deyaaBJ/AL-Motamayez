import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:motamayez/constant/constant.dart';
import 'package:motamayez/db/db_helper.dart';
import 'package:motamayez/services/encryption_service.dart';

class ActivationException implements Exception {
  final String message;
  final String? storedSignature;
  final String? expectedSignature;

  ActivationException(
    this.message, {
    this.storedSignature,
    this.expectedSignature,
  });

  @override
  String toString() => message;
}

class ActivationService {
  final DBHelper _dbHelper = DBHelper();

  static const String _secretKey = AppConstants.secretKey;
  static final String _serverUrl = AppConstants.serverUrl;

  String? _maskValue(String? value) {
    if (value == null || value.isEmpty) return value;
    if (value.length <= 8) return '***';
    return '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
  }

  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');

    if (deviceId != null && deviceId.isNotEmpty) {
      return deviceId;
    }

    deviceId = const Uuid().v4();
    await prefs.setString('device_id', deviceId);
    return deviceId;
  }

  String _generateSignature(String deviceId) {
    final raw = '$deviceId|$_secretKey';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  Future<void> _ensureActivationTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activation (
        id INTEGER PRIMARY KEY,
        signature TEXT,
        activation_code TEXT
      )
    ''');
  }

  Future<void> _saveSignature(String signature) async {
    final encrypted = EncryptionService.encrypt(signature);
    final db = await _dbHelper.db;
    await _ensureActivationTable(db);
    await db.delete('activation');
    await db.insert(
      'activation',
      {'id': 1, 'signature': encrypted},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activation_signature', encrypted);
  }

  Future<void> _saveActivationCode(String code) async {
    final db = await _dbHelper.db;
    await _ensureActivationTable(db);
    await db.update('activation', {'activation_code': code}, where: 'id = 1');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activation_code', code);
  }

  Future<String?> _getStoredSignature() async {
    try {
      final db = await _dbHelper.db;
      await _ensureActivationTable(db);

      final result = await db.query('activation', limit: 1);
      if (result.isNotEmpty) {
        final encrypted = result.first['signature'] as String?;
        if (encrypted == null || encrypted.isEmpty) return null;
        return EncryptionService.decrypt(encrypted);
      }

      final prefs = await SharedPreferences.getInstance();
      final encrypted = prefs.getString('activation_signature');
      if (encrypted == null || encrypted.isEmpty) return null;

      await db.insert(
        'activation',
        {'id': 1, 'signature': encrypted},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return EncryptionService.decrypt(encrypted);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getStoredActivationCode() async {
    try {
      final db = await _dbHelper.db;
      await _ensureActivationTable(db);
      final result = await db.query('activation', limit: 1);
      if (result.isNotEmpty && result.first.containsKey('activation_code')) {
        return result.first['activation_code'] as String?;
      }

      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('activation_code');
    } catch (_) {
      return null;
    }
  }

  Future<bool> activate(String activationCode) async {
    try {
      final deviceId = await getDeviceId();
      final response = await http
          .post(
            Uri.parse(_serverUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'code': activationCode, 'deviceId': deviceId}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return false;
      }

      final data = jsonDecode(response.body);
      if (data['success'] != true) {
        return false;
      }

      final signature = _generateSignature(deviceId);
      await _saveSignature(signature);
      await _saveActivationCode(activationCode);
      return true;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isActivated() async {
    final storedSignature = await _getStoredSignature();
    if (storedSignature == null) {
      return false;
    }

    final deviceId = await getDeviceId();
    final expectedSignature = _generateSignature(deviceId);

    if (storedSignature != expectedSignature) {
      throw ActivationException(
        'Activation signature mismatch.',
        storedSignature: _maskValue(storedSignature),
        expectedSignature: _maskValue(expectedSignature),
      );
    }

    return true;
  }

  Future<bool> checkActivationSilently() async {
    try {
      final storedSignature = await _getStoredSignature();
      if (storedSignature == null) return false;
      final deviceId = await getDeviceId();
      return storedSignature == _generateSignature(deviceId);
    } catch (_) {
      return false;
    }
  }

  Future<void> clearActivation() async {
    try {
      final db = await _dbHelper.db;
      await _ensureActivationTable(db);
      await db.delete('activation');

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('activation_signature');
      await prefs.remove('activation_code');
      await prefs.remove('device_id');
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getActivationInfo() async {
    try {
      final db = await _dbHelper.db;
      await _ensureActivationTable(db);
      final result = await db.query('activation', limit: 1);

      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? 'Unavailable';
      final activationCode = prefs.getString('activation_code');

      final storedSignature = await _getStoredSignature();
      final expectedSignature =
          deviceId == 'Unavailable' ? null : _generateSignature(deviceId);

      return {
        'device_id': _maskValue(deviceId),
        'activation_code': activationCode,
        'stored_signature': _maskValue(storedSignature),
        'expected_signature': _maskValue(expectedSignature),
        'is_valid': storedSignature != null && storedSignature == expectedSignature,
        'has_activation': result.isNotEmpty,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<void> checkDatabase() async {
    final db = await _dbHelper.db;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    for (final table in tables) {
      final tableName = table['name'];
      if (tableName == null) continue;
      try {
        await db.rawQuery("SELECT COUNT(*) as count FROM $tableName");
      } catch (_) {}
    }
  }
}
