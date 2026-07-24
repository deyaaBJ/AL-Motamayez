import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LicenseStorage {
  LicenseStorage({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;

  static const String _licenseCacheKey = 'license_cache_v3';
  static const String _requestIdKey = 'activation_request_id';
  static const String _requestStatusKey = 'activation_request_status';
  static const String _requestCodeKey = 'activation_request_code';
  static const String _legacyActivationStateKey = 'activation_state_v2';
  static const String _legacyActivationMetadataKey = 'activation_metadata';
  static const String _legacyActivationPayloadKey = 'activation_payload';
  static const String _legacyActivationSignatureKey = 'activation_signature';
  static const String _legacyActivationCodeKey = 'activation_code';

  Future<Map<String, dynamic>?> readLicenseCache() async {
    final raw = await _readProtectedValue(_licenseCacheKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    return null;
  }

  Future<void> saveLicenseCache(Map<String, dynamic> state) async {
    final encoded = jsonEncode(state);
    await _writeProtectedValue(_licenseCacheKey, encoded);
  }

  Future<void> clearLicenseCache() async {
    await _deleteProtectedValue(_licenseCacheKey);
  }

  Future<void> savePendingRequest({
    required String requestId,
    required String status,
    String? assignedCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_requestIdKey, requestId);
    await prefs.setString(_requestStatusKey, status);
    if (assignedCode != null && assignedCode.trim().isNotEmpty) {
      await prefs.setString(_requestCodeKey, assignedCode.trim());
    }
  }

  Future<void> clearPendingRequest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_requestIdKey);
    await prefs.remove(_requestStatusKey);
    await prefs.remove(_requestCodeKey);
  }

  Future<Map<String, dynamic>?> getSavedPendingRequest() async {
    final prefs = await SharedPreferences.getInstance();
    final requestId = prefs.getString(_requestIdKey);
    if (requestId == null || requestId.isEmpty) {
      return null;
    }

    return {
      'requestId': requestId,
      'status': prefs.getString(_requestStatusKey) ?? 'pending',
      'assignedCode': prefs.getString(_requestCodeKey),
    };
  }

  Future<void> clearPendingRequestCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_requestCodeKey);
  }

  Future<bool> hasLegacySensitiveState() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_legacyActivationStateKey) ||
        prefs.containsKey(_legacyActivationMetadataKey) ||
        prefs.containsKey(_legacyActivationPayloadKey) ||
        prefs.containsKey(_legacyActivationSignatureKey) ||
        prefs.containsKey(_legacyActivationCodeKey);
  }

  Future<Map<String, dynamic>?> readLegacyActivationState() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_legacyActivationStateKey);
    if (encoded == null || encoded.isEmpty) return null;

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    return null;
  }

  Future<void> clearLegacySensitiveState() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_legacyActivationStateKey),
      prefs.remove(_legacyActivationMetadataKey),
      prefs.remove(_legacyActivationPayloadKey),
      prefs.remove(_legacyActivationSignatureKey),
      prefs.remove(_legacyActivationCodeKey),
    ]);
  }

  Future<String?> _readProtectedValue(String key) async {
    try {
      final value = await _secureStorage.read(key: key);
      if (value != null && value.isNotEmpty) return value;
    } catch (_) {}
    return null;
  }

  Future<void> _writeProtectedValue(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  Future<void> _deleteProtectedValue(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {}
  }

  static String computeIntegrityHash(Map<String, dynamic> state) {
    final copy = Map<String, dynamic>.from(state)..remove('integrity');
    return sha256.convert(utf8.encode(jsonEncode(copy))).toString();
  }
}
