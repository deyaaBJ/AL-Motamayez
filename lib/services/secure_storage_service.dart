import 'package:shared_preferences/shared_preferences.dart';

/// خدمة التخزين لـ "تذكرني" - تحفظ آخر مستخدم دخل
class SecureStorageService {
  static const String _keyEmail = 'last_saved_email';
  static const String _keyPassword = 'last_saved_password';
  static const String _keyRememberMe = 'remember_me_enabled';
  static const String _keyLastUserId = 'last_user_id';

  /// حفظ بيانات آخر مستخدم دخل (يستبدل القديم)
  static Future<void> saveCredentials(
    String email,
    String password, {
    String? userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await Future.wait([
        prefs.setString(_keyEmail, email),
        prefs.setString(_keyPassword, password),
        prefs.setBool(_keyRememberMe, true),
        if (userId != null) prefs.setString(_keyLastUserId, userId),
      ]);

      print('✅ Saved last user: $email');
    } catch (e) {
      print('❌ Error saving credentials: $e');
    }
  }

  /// استرجاع بيانات آخر مستخدم محفوظ
  static Future<Map<String, String>?> getSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final rememberMe = prefs.getBool(_keyRememberMe) ?? false;
      if (!rememberMe) {
        print('ℹ️ Remember me is disabled');
        return null;
      }

      final email = prefs.getString(_keyEmail);
      final password = prefs.getString(_keyPassword);

      if (email == null ||
          password == null ||
          email.isEmpty ||
          password.isEmpty) {
        print('ℹ️ No saved credentials found');
        return null;
      }

      print('✅ Retrieved last user: $email');

      return {'email': email, 'password': password};
    } catch (e) {
      print('❌ Error retrieving credentials: $e');
      return null;
    }
  }

  /// مسح البيانات المحفوظة (عند تسجيل الخروج)
  static Future<void> clearCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await Future.wait([
        prefs.remove(_keyEmail),
        prefs.remove(_keyPassword),
        prefs.remove(_keyRememberMe),
        prefs.remove(_keyLastUserId),
      ]);

      print('✅ Credentials cleared');
    } catch (e) {
      print('❌ Error clearing credentials: $e');
    }
  }

  /// تعطيل "تذكرني" بدون مسح البيانات (اختياري)
  static Future<void> disableRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRememberMe, false);
  }
}
