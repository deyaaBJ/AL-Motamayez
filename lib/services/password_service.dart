import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class PasswordService {
  static const int _saltLength = 16;
  static const String _separator = ':';

  static String hashPassword(String password) {
    final salt = _generateSalt();
    final hash = _hash(password, salt);
    return '$salt$_separator$hash';
  }

  static bool verifyPassword(String password, String storedValue) {
    if (storedValue.isEmpty) return false;

    if (isLegacyPlaintext(storedValue)) {
      return password == storedValue;
    }

    final parts = storedValue.split(_separator);
    if (parts.length != 2) return false;

    final salt = parts[0];
    final expectedHash = parts[1];
    final actualHash = _hash(password, salt);
    return actualHash == expectedHash;
  }

  static bool isLegacyPlaintext(String storedValue) {
    return !storedValue.contains(_separator);
  }

  static String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String _hash(String password, String salt) {
    return sha256.convert(utf8.encode('$salt|$password')).toString();
  }
}
