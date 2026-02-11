import 'dart:io';
import 'package:flutter/material.dart';
import 'package:motamayez/utils/app_config.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../db/db_helper.dart';
import '../services/secure_storage_service.dart';
import 'package:archive/archive_io.dart';
import 'dart:developer';

class AuthProvider with ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get role => _currentUser?['role'];
  bool get isLoggedIn => _currentUser != null;

  // ================================
  // LOGIN مع "تذكرني"
  // ================================
  Future<bool> login(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    try {
      final db = await _dbHelper.db;
      final result = await db.query(
        'users',
        where: 'email = ? AND password = ?',
        whereArgs: [email, password],
      );

      if (result.isNotEmpty) {
        _currentUser = result.first;

        // ✅ حفظ البيانات إذا اختار "تذكرني"
        if (rememberMe) {
          await SecureStorageService.saveCredentials(email, password);
          log('✅ Saved credentials for: $email');
        }

        notifyListeners();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      log('Login error: $e');
      return false;
    }
  }

  // ================================
  // جلب البيانات المحفوظة للـ UI
  // ================================
  Future<Map<String, String>?> getSavedCredentialsForLogin() async {
    return await SecureStorageService.getSavedCredentials();
  }

  // ================================
  // تسجيل الخروج - نسخ + حذف
  // ================================
  Future<void> logout() async {
    try {
      await _createBackupWithCleanup();
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      log('❌ خطأ في تسجيل الخروج: $e');
    }
  }

  // ================================
  // نسخ + حذف عند إغلاق التطبيق
  // ================================
  Future<void> backupAndCleanOnClose() async {
    try {
      if (_currentUser == null) {
        log('⚠️ لا يمكن النسخ: المستخدم غير مسجل دخول');
        return;
      }

      await _createBackupWithCleanup();
      log('✅ تم النسخ والحذف للإغلاق بنجاح');
    } catch (e) {
      log('❌ خطأ في النسخ للإغلاق: $e');
      await _createQuickBackupOnly();
    }
  }

  // ================================
  // الدالة الأساسية: نسخ + حذف
  // ================================
  Future<void> _createBackupWithCleanup() async {
    final Stopwatch stopwatch = Stopwatch()..start();

    try {
      if (_currentUser == null) {
        log('⚠️ لا يمكن إنشاء نسخة: لم يتم تسجيل الدخول');
        return;
      }

      final db = await _dbHelper.db;
      await db.execute('VACUUM');

      final dbPath = db.path;
      final sourceFile = File(dbPath);

      if (!sourceFile.existsSync()) {
        log('❌ ملف قاعدة البيانات غير موجود!');
        return;
      }

      // ✅ مسار النسخ من config.json فقط
      final appConfig = AppConfig(
        configFilePath: p.join(p.current, 'config.json'),
      );

      final backupDirPath = await appConfig.getBackupFolderPath();
      final backupDir = Directory(backupDirPath);
      if (!backupDir.existsSync()) {
        backupDir.createSync(recursive: true);
      }

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');

      final dbBackupPath = p.join(
        backupDir.path,
        'motamayez_backup_$timestamp.db',
      );

      try {
        sourceFile.copySync(dbBackupPath);
      } catch (_) {
        await sourceFile.copy(dbBackupPath);
      }

      final dbBackupFile = File(dbBackupPath);
      if (!dbBackupFile.existsSync()) {
        throw Exception('❌ فشل إنشاء نسخة قاعدة البيانات');
      }

      log('✅ تم إنشاء نسخة DB: ${p.basename(dbBackupPath)}');

      final zipPath = p.join(backupDir.path, 'motamayez_backup_$timestamp.zip');

      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      encoder.addFile(dbBackupFile);
      encoder.close();

      final zipFile = File(zipPath);

      if (!zipFile.existsSync()) {
        throw Exception('❌ فشل ضغط النسخة');
      }

      log('📦 تم ضغط النسخة: ${p.basename(zipPath)}');

      await dbBackupFile.delete();

      // ✅ عدد النسخ من قاعدة البيانات فقط
      final int numberOfCopiesToKeep = await _getNumberOfCopiesFromSettings();

      final backups =
          backupDir
              .listSync()
              .whereType<File>()
              .where(
                (f) =>
                    f.path.endsWith('.zip') &&
                    p.basename(f.path).startsWith('motamayez_backup_'),
              )
              .toList()
            ..sort(
              (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
            );

      while (backups.length > numberOfCopiesToKeep) {
        final oldest = backups.removeAt(0);
        await oldest.delete();
        log('🗑 تم حذف نسخة قديمة: ${p.basename(oldest.path)}');
      }

      log('⏱️ الوقت المستغرق: ${stopwatch.elapsedMilliseconds}ms');
      log('🎉 اكتملت عملية النسخ الاحتياطي بنجاح');
      log('📊 عدد النسخ المحفوظ: $numberOfCopiesToKeep');
      log('📊 عدد النسخ الحالية بعد التنظيف: ${backups.length}');
    } catch (e) {
      log('❌ خطأ في النسخ الاحتياطي: $e');
      rethrow;
    }
  }

  // ================================
  // دالة للحصول على عدد النسخ من قاعدة البيانات
  // ================================
  Future<int> _getNumberOfCopiesFromSettings() async {
    try {
      final db = await _dbHelper.db;

      final result = await db.query(
        'settings',
        columns: ['numberOfCopies'],
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );

      if (result.isNotEmpty) {
        final numberOfCopies = result.first['numberOfCopies'];

        if (numberOfCopies is int) {
          return numberOfCopies;
        } else if (numberOfCopies is String) {
          return int.tryParse(numberOfCopies) ?? 1;
        } else if (numberOfCopies != null) {
          return numberOfCopies as int;
        }
      }

      return 1; // قيمة افتراضية فقط إذا ما لقينا شي في الـ DB
    } catch (e) {
      log('❌ خطأ في قراءة numberOfCopies: $e');
      return 1;
    }
  }

  // ================================
  // نسخة طارئة سريعة - بنفس الطريقة
  // ================================
  Future<void> _createQuickBackupOnly() async {
    try {
      if (_currentUser == null) {
        log('⚠️ لا يمكن إنشاء نسخة طارئة: المستخدم غير مسجل دخول');
        return;
      }

      final db = await _dbHelper.db;
      final dbPath = db.path;

      // ✅ من config.json
      final appConfig = AppConfig(
        configFilePath: p.join(p.current, 'config.json'),
      );
      final backupDirPath = await appConfig.getBackupFolderPath();

      final backupDir = Directory(backupDirPath);
      if (!backupDir.existsSync()) {
        backupDir.createSync(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final backupFilePath = '${backupDir.path}/motamayez_backup_$timestamp.db';

      File(dbPath).copySync(backupFilePath);

      log('⚡ تم إنشاء نسخة طارئة: ${p.basename(backupFilePath)}');

      final logFile = File('${backupDir.path}/backup_log.txt');
      final logEntry =
          '[${DateTime.now()}] ⚡ نسخة طارئة: ${p.basename(backupFilePath)}\n';
      try {
        logFile.writeAsStringSync(logEntry, mode: FileMode.append);
      } catch (_) {}
    } catch (e) {
      log('❌ حتى النسخة الطارئة فشلت: $e');
    }
  }

  // ================================
  // إدارة المستخدمين - الكاشيرز
  // ================================

  /// جلب جميع المستخدمين حسب الدور
  Future<List<Map<String, dynamic>>> getUsersByRole(String role) async {
    try {
      final db = await _dbHelper.db;
      final result = await db.query(
        'users',
        where: 'role = ?',
        whereArgs: [role],
      );
      return result;
    } catch (e) {
      log('Error fetching users by role: $e');
      return [];
    }
  }

  /// ✅ دالة جديدة: جلب جميع الإيميلات (للـ Debug)
  Future<List<String>> getAllEmails() async {
    try {
      final db = await _dbHelper.db;
      final result = await db.query('users', columns: ['email']);
      return result.map((row) => row['email'].toString()).toList();
    } catch (e) {
      log('ERROR_GET_EMAILS=$e');
      return [];
    }
  }

  Future<bool> createUser({
    required String role,
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final db = await _dbHelper.db;

      // ✅ تطهير الإيميل
      final cleanEmail = email.trim().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        '',
      );
      final cleanName = name.trim();

      print('🔍 إضافة مستخدم: $cleanName / $cleanEmail');

      // ✅ التحقق من وجود الإيميل
      final existing = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [cleanEmail],
      );

      if (existing.isNotEmpty) {
        print('❌ الإيميل موجود مسبقاً');
        return false;
      }

      print('✅ إدراج جديد...');

      // ✅ إدراج بدون created_at
      final id = await db.insert('users', {
        'name': cleanName,
        'email': cleanEmail,
        'password': password,
        'role': role,
        // ❌ تم إزالة 'created_at'
      }, conflictAlgorithm: ConflictAlgorithm.fail);

      print('✅ تم الإدراج بـ ID: $id');
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ خطأ: $e');
      return false;
    }
  }

  /// تحديث بيانات مستخدم (باستخدام ID أو role للأدمن)
  Future<bool> updateUserDataByRole({
    String? userId, // ✅ إضافة ID للكاشير المحدد
    required String role,
    required String name,
    required String email,
    String? phone,
  }) async {
    try {
      final db = await _dbHelper.db;

      Map<String, dynamic> updateData = {'name': name, 'email': email};

      if (phone != null) {
        updateData['phone'] = phone;
      }

      int result;

      if (userId != null) {
        // ✅ تحديث كاشير محدد بالـ ID
        result = await db.update(
          'users',
          updateData,
          where: 'id = ? AND role = ?',
          whereArgs: [userId, role],
        );
      } else {
        // تحديث بالـ role (للأدمن)
        result = await db.update(
          'users',
          updateData,
          where: 'role = ?',
          whereArgs: [role],
        );
      }

      // تحديث currentUser إذا كان هو المستخدم المحدث
      if (_currentUser != null &&
          (_currentUser!['role'] == role ||
              _currentUser!['id'].toString() == userId)) {
        _currentUser!['name'] = name;
        _currentUser!['email'] = email;
        if (phone != null) _currentUser!['phone'] = phone;
        notifyListeners();
      }

      log('✅ تم تحديث بيانات المستخدم: $name');
      return result > 0;
    } catch (e) {
      log('❌ Error updating user data: $e');
      return false;
    }
  }

  /// حذف مستخدم
  Future<bool> deleteUser(String userId) async {
    try {
      final db = await _dbHelper.db;

      final result = await db.delete(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );

      log('✅ تم حذف المستخدم ID: $userId');
      notifyListeners();
      return result > 0;
    } catch (e) {
      log('❌ Error deleting user: $e');
      return false;
    }
  }

  /// تغيير كلمة المرور
  Future<bool> changePasswordByRole({
    required String role,
    String? userId, // ✅ إضافة ID للكاشير المحدد
    String? oldPassword,
    required String newPassword,
  }) async {
    try {
      final db = await _dbHelper.db;

      int result;

      if (userId != null) {
        // ✅ تغيير كلمة مرور كاشير محدد
        result = await db.update(
          'users',
          {'password': newPassword},
          where: 'id = ? AND role = ?',
          whereArgs: [userId, role],
        );
      } else {
        // تغيير بالـ role + oldPassword (للأدمن)
        final users = await db.query(
          'users',
          where: 'role = ? AND password = ?',
          whereArgs: [role, oldPassword],
        );

        if (users.isEmpty) {
          return false;
        }

        result = await db.update(
          'users',
          {'password': newPassword},
          where: 'role = ?',
          whereArgs: [role],
        );
      }

      log('✅ تم تغيير كلمة المرور للمستخدم ID: $userId, Role: $role');
      return result > 0;
    } catch (e) {
      log('❌ Error changing password: $e');
      return false;
    }
  }

  /// جلب مستخدم واحد بالـ ID
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final db = await _dbHelper.db;
      final result = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return result.first;
      }
      return null;
    } catch (e) {
      log('Error fetching user by ID: $e');
      return null;
    }
  }
}
