import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:motamayez/constant/constant.dart';
import 'package:motamayez/db/db_helper.dart';
import 'package:motamayez/services/encryption_service.dart';

class ActivationService {
  final DBHelper _dbHelper = DBHelper();

  static const String _secretKey = AppConstants.secretKey;
  static final String _serverUrl = AppConstants.serverUrl;

  /// Device ID ثابت
  Future<String> getDeviceId() async {
    try {
      // استخدام SharedPreferences كبديل أكثر استقراراً
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');

      if (deviceId != null && deviceId.isNotEmpty) {
        print('📱 Device ID from SharedPreferences: $deviceId');
        return deviceId;
      }

      // إنشاء ID جديد
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
      print('🆕 New Device ID generated: $deviceId');
      return deviceId;
    } catch (e) {
      print('❌ Error getDeviceId: $e');
      rethrow;
    }
  }

  /// توليد توقيع للجهاز
  String _generateSignature(String deviceId) {
    final raw = '$deviceId|$_secretKey';
    final signature = sha256.convert(utf8.encode(raw)).toString();
    print('🔄 Generated signature: $signature');
    print('🔄 From deviceId: $deviceId');
    print('🔄 And secretKey: $_secretKey');
    return signature;
  }

  /// حفظ التوقيع مشفر في SQLite
  Future<void> _saveSignature(String signature) async {
    try {
      print('💾 Saving signature to database...');
      final encrypted = EncryptionService.encrypt(signature);
      print('🔐 Encrypted signature: $encrypted');

      final db = await _dbHelper.db;

      // تأكد من وجود جدول activation
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='activation'",
      );

      if (tables.isEmpty) {
        print('⚠️ Activation table not found, creating...');
        await db.execute('''
          CREATE TABLE activation (
            id INTEGER PRIMARY KEY,
            signature TEXT
          )
        ''');
      }

      // حذف أي بيانات موجودة
      await db.delete('activation');

      // إدراج البيانات الجديدة
      final result = await db.insert('activation', {
        'id': 1,
        'signature': encrypted,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      print('✅ Signature inserted successfully, ID: $result');

      // التحقق من الحفظ
      final check = await db.query('activation');
      print('📋 Activation data after saving: $check');

      // حفظ نسخة في SharedPreferences أيضاً كنسخة احتياطية
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('activation_signature', encrypted);
      print('📱 Backup saved to SharedPreferences');
    } catch (e) {
      print('❌ Error saving signature: $e');
      print('Stack trace: ${e.toString()}');
      rethrow;
    }
  }

  /// قراءة التوقيع وفك التشفير
  Future<String?> _getStoredSignature() async {
    try {
      print('🔍 Reading signature...');

      // أولاً: حاول من SQLite
      final db = await _dbHelper.db;

      // تحقق من وجود الجدول
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='activation'",
      );

      if (tables.isEmpty) {
        print('📭 Activation table does not exist');
        return null;
      }

      final result = await db.query('activation', limit: 1);

      if (result.isNotEmpty) {
        final encrypted = result.first['signature'] as String;
        print('💾 Signature from SQLite: $encrypted');
        final decrypted = EncryptionService.decrypt(encrypted);
        print('🔓 Decrypted signature: $decrypted');
        return decrypted;
      }

      // ثانياً: حاول من SharedPreferences إذا فشل SQLite
      final prefs = await SharedPreferences.getInstance();
      final encrypted = prefs.getString('activation_signature');

      if (encrypted != null) {
        print('📱 Signature from SharedPreferences: $encrypted');
        final decrypted = EncryptionService.decrypt(encrypted);
        print('🔓 Decrypted signature: $decrypted');

        // حفظ في SQLite للاستخدام المستقبلي
        await db.insert('activation', {
          'id': 1,
          'signature': encrypted,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        return decrypted;
      }

      print('⚠️ No signatures stored');
      return null;
    } catch (e) {
      print('❌ Error reading signature: $e');
      return null;
    }
  }

  /// تفعيل الجهاز عبر السيرفر
  Future<bool> activate(String activationCode) async {
    try {
      print('🚀 Starting activation process...');

      final deviceId = await getDeviceId();
      print('📱 Device ID: $deviceId');

      // إرسال طلب التفعيل
      final response = await http
          .post(
            Uri.parse(_serverUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'code': activationCode, 'deviceId': deviceId}),
          )
          .timeout(const Duration(seconds: 30));

      print('🌐 Server response: ${response.statusCode} - ${response.body}');

      if (response.statusCode != 200) {
        print('❌ Failed to connect to server');
        return false;
      }

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        print('✅ Code activated successfully');

        // توليد وحفظ التوقيع
        final signature = _generateSignature(deviceId);
        await _saveSignature(signature);

        // التحقق من الحفظ
        final stored = await _getStoredSignature();
        if (stored == signature) {
          print('🎉 Activation confirmed and saved successfully!');
          return true;
        } else {
          print(
            '⚠️ Signature verification failed, but activation was approved by server',
          );
          return true; // نعيد true لأن السيرفر وافق
        }
      }

      print('❌ Invalid activation code');
      return false;
    } on TimeoutException catch (_) {
      print('⏰ Connection timeout');
      return false;
    } catch (e) {
      print('❌ Activation error: $e');
      return false;
    }
  }

  /// فحص التفعيل
  Future<bool> isActivated() async {
    try {
      print('🔍 Checking activation status...');

      final storedSignature = await _getStoredSignature();

      if (storedSignature == null) {
        print('📭 No stored signature found');
        return false;
      }

      final deviceId = await getDeviceId();
      final expectedSignature = _generateSignature(deviceId);

      print('🔍 Comparing signatures:');
      print('   Stored: $storedSignature');
      print('   Expected: $expectedSignature');

      if (storedSignature != expectedSignature) {
        print('❌ Signatures do not match');
        return false;
      }

      print('✅ Activation is valid');
      return true;
    } catch (e) {
      print('❌ Error checking activation: $e');
      return false;
    }
  }

  /// إلغاء التفعيل
  Future<void> clearActivation() async {
    try {
      final db = await _dbHelper.db;
      await db.delete('activation');

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('activation_signature');
      await prefs.remove('device_id');

      print('🧹 Activation data cleared');
    } catch (e) {
      print('❌ Error clearing activation: $e');
    }
  }

  /// فحص قاعدة البيانات
  Future<void> checkDatabase() async {
    try {
      final db = await _dbHelper.db;
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      print('=== Database Check ===');
      for (var table in tables) {
        final tableName = table['name'];
        try {
          final count = await db.rawQuery(
            "SELECT COUNT(*) as count FROM $tableName",
          );
          final data = await db.query(tableName.toString(), limit: 3);
          print('Table: $tableName - Records: ${count.first['count']}');
          print('   Data: $data');
        } catch (e) {
          print('Table: $tableName - Error: $e');
        }
      }
      print('=== End Check ===');
    } catch (e) {
      print('Database check error: $e');
    }
  }
}
