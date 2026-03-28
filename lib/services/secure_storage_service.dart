import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static const String _keyEmail = 'last_saved_email';
  static const String _keyPassword = 'last_saved_password';
  static const String _keyRememberMe = 'remember_me_enabled';
  static const String _keyLastUserId = 'last_user_id';

  static Future<void> saveCredentials(String email, {String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString(_keyEmail, email),
        prefs.remove(_keyPassword),
        prefs.setBool(_keyRememberMe, true),
        if (userId != null) prefs.setString(_keyLastUserId, userId),
      ]);
    } catch (_) {}
  }

  static Future<Map<String, String>?> getSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool(_keyRememberMe) ?? false;
      if (!rememberMe) return null;

      final email = prefs.getString(_keyEmail);
      if (email == null || email.isEmpty) return null;

      // Clear any legacy stored plaintext password on first read.
      await prefs.remove(_keyPassword);
      return {'email': email};
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_keyEmail),
        prefs.remove(_keyPassword),
        prefs.remove(_keyRememberMe),
        prefs.remove(_keyLastUserId),
      ]);
    } catch (_) {}
  }

  static Future<void> disableRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRememberMe, false);
    await prefs.remove(_keyPassword);
  }
}
