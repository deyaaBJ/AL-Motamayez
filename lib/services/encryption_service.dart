import 'dart:convert';

class EncryptionService {
  static String encrypt(String value) {
    try {
      return base64.encode(utf8.encode(value));
    } catch (_) {
      return value;
    }
  }

  static String decrypt(String value) {
    try {
      return utf8.decode(base64.decode(value));
    } catch (_) {
      return value;
    }
  }
}
