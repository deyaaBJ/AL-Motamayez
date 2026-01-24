import 'dart:convert';

class EncryptionService {
  // تشفير بسيط باستخدام base64 فقط
  static String encrypt(String value) {
    try {
      print('🔐 جاري تشفير (base64): $value');
      final bytes = utf8.encode(value);
      final encrypted = base64.encode(bytes);
      print('✅ التشفير ناجح: $encrypted');
      return encrypted;
    } catch (e) {
      print('❌ خطأ في التشفير: $e');
      return value; // إذا فشل التشفير نرجع القيمة الأصلية
    }
  }

  static String decrypt(String value) {
    try {
      print('🔓 جاري فك تشفير (base64): $value');
      final bytes = base64.decode(value);
      final decrypted = utf8.decode(bytes);
      print('✅ فك التشفير ناجح: $decrypted');
      return decrypted;
    } catch (e) {
      print('❌ خطأ في فك التشفير: $e');
      return value; // إذا فشل فك التشفير نرجع القيمة المشفرة
    }
  }
}
