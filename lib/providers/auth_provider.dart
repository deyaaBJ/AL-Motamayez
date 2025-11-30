import 'package:flutter/material.dart';
import '../db/db_helper.dart';

class AuthProvider with ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? get currentUser => _currentUser;

  // ================================
  // تسجيل الدخول
  // ================================
  Future<bool> login(String email, String password) async {
    try {
      final db = await _dbHelper.db;
      final result = await db.query(
        'users',
        where: 'email = ? AND password = ?',
        whereArgs: [email, password],
      );

      print('Login query result: $result');

      if (result.isNotEmpty) {
        _currentUser = result.first; // حفظ بيانات المستخدم الحالي
        notifyListeners();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  // ================================
  // الحصول على الدور
  // ================================
  String? get role => _currentUser?['role'];

  // ================================
  // تسجيل الخروج
  // ================================
  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  // ================================
  // جلب بيانات كل المستخدمين حسب الدور
  // ================================
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
      print('Error fetching users by role: $e');
      return [];
    }
  }

  // ================================
  // تعديل بيانات المستخدم حسب الدور (role)
  // ================================
  Future<void> updateUserDataByRole({
    required String role,
    required String name,
    required String email,
  }) async {
    try {
      final db = await _dbHelper.db;

      // تحديث المستخدم الذي يطابق الدور
      await db.update(
        'users',
        {'name': name, 'email': email},
        where: 'role = ?',
        whereArgs: [role],
      );

      // إذا المستخدم الحالي هو نفس الدور، حدث الكائن في الذاكرة
      if (_currentUser != null && _currentUser!['role'] == role) {
        _currentUser!['name'] = name;
        _currentUser!['email'] = email;
        notifyListeners();
      }
    } catch (e) {
      print('Error updating user data by role: $e');
    }
  }

  // ================================
  // تغيير كلمة المرور لمستخدم حسب الدور (role)
  // ================================
  // في ملف auth_provider.dart
  Future<bool> changePasswordByRole({
    required String role,
    required String oldPassword,
    required String newPassword,
  }) async {
    final db = await _dbHelper.db;
    try {
      // التحقق من كلمة المرور القديمة أولاً
      final users = await db.query(
        'users',
        where: 'role = ? AND password = ?',
        whereArgs: [role, oldPassword],
      );

      if (users.isEmpty) {
        return false; // كلمة المرور القديمة غير صحيحة
      }

      // تحديث كلمة المرور
      final result = await db.update(
        'users',
        {'password': newPassword},
        where: 'role = ?',
        whereArgs: [role],
      );

      return result > 0;
    } catch (e) {
      print('Error changing password: $e');
      return false;
    }
  }
}
