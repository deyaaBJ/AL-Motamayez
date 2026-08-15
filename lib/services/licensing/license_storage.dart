import 'dart:io';
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
  static const String _licenseCacheBackupKey = 'license_cache_v3_backup';
  static const String _licenseStatusSnapshotKey = 'license_status_snapshot_v1';
  static const String _databaseFingerprintKey = 'database_fingerprint_v1';
  static const String _secureStorageCorruptFlagKey =
      'secure_storage_corrupt_v1';
  static const String _windowsProtectedPrefix = 'windows_protected_v1_';

  Future<Map<String, dynamic>?> readLicenseCache() async {
    final raw = await _readProtectedValue(_licenseCacheKey);
    if (raw == null || raw.isEmpty) {
      return _readBackupLicenseCache();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    return _readBackupLicenseCache();
  }

  Future<void> saveLicenseCache(Map<String, dynamic> state) async {
    final encoded = jsonEncode(state);
    await _writeProtectedValue(_licenseCacheKey, encoded);
    await _writeBackupLicenseCache(encoded);
    await _writeStatusSnapshot(state);
  }

  Future<void> clearLicenseCache() async {
    await _deleteProtectedValue(_licenseCacheKey);
    await _deleteProtectedValue(_databaseFingerprintKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_licenseCacheBackupKey);
    await prefs.remove(_licenseStatusSnapshotKey);
  }

  Future<void> saveDatabaseFingerprint(Map<String, dynamic> fingerprint) async {
    await _writeProtectedValue(_databaseFingerprintKey, jsonEncode(fingerprint));
  }

  Future<Map<String, dynamic>?> readDatabaseFingerprint() async {
    final raw = await _readProtectedValue(_databaseFingerprintKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
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
    if (Platform.isWindows) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final value = prefs.getString('$_windowsProtectedPrefix$key');
        if (value != null && value.isNotEmpty) return value;
      } catch (_) {}

      // Keep the old storage file out of the way so the Windows app stops
      // hitting CryptUnprotectData() on every launch.
      await _removeCorruptWindowsStorageFile();
      return null;
    }

    if (await _isSecureStorageMarkedCorrupt()) {
      return null;
    }

    try {
      final value = await _secureStorage.read(key: key);
      if (value != null && value.isNotEmpty) return value;
      await _clearSecureStorageCorruptFlag();
    } catch (_) {
      // If the protected store is corrupted, fall back to shared preferences.
      await _removeCorruptWindowsStorageFile();
      await _markSecureStorageCorrupt();
      await _deleteProtectedValue(key);
    }
    return null;
  }

  Future<void> _writeProtectedValue(String key, String value) async {
    if (Platform.isWindows) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$_windowsProtectedPrefix$key', value);
      } catch (_) {
        await _writeBackupLicenseCache(value);
      }
      return;
    }

    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {
      await _writeBackupLicenseCache(value);
    }
  }

  Future<void> _deleteProtectedValue(String key) async {
    if (Platform.isWindows) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('$_windowsProtectedPrefix$key');
      } catch (_) {}
      return;
    }

    try {
      await _secureStorage.delete(key: key);
    } catch (_) {}
  }

  Future<bool> _isSecureStorageMarkedCorrupt() async {
    if (!Platform.isWindows) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_secureStorageCorruptFlagKey) == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _markSecureStorageCorrupt() async {
    if (!Platform.isWindows) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_secureStorageCorruptFlagKey, true);
    } catch (_) {}
  }

  Future<void> _clearSecureStorageCorruptFlag() async {
    if (!Platform.isWindows) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_secureStorageCorruptFlagKey);
    } catch (_) {}
  }

  Future<void> _removeCorruptWindowsStorageFile() async {
    if (!Platform.isWindows) return;

    try {
      final appData = Platform.environment['APPDATA'];
      if (appData == null || appData.isEmpty) return;

      final storageDir = Directory(
        '$appData\\com.example\\motamayez',
      );
      final storageFile = File('${storageDir.path}\\flutter_secure_storage.dat');

      if (await storageFile.exists()) {
        await storageFile.delete();
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _readBackupLicenseCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_licenseCacheBackupKey);
      if (encoded == null || encoded.isEmpty) return null;

      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> readStatusSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_licenseStatusSnapshotKey);
      if (encoded == null || encoded.isEmpty) return null;

      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _writeBackupLicenseCache(String encoded) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_licenseCacheBackupKey, encoded);
    } catch (_) {}
  }

  Future<void> _writeStatusSnapshot(Map<String, dynamic> state) async {
    try {
      final snapshot = <String, dynamic>{
        'has_activation': true,
        'status': state['licenseStatus']?.toString() ?? 'valid',
        'activation_type': state['licenseType']?.toString() ?? 'permanent',
        'license_id': state['licenseId']?.toString(),
        'expires_at': state['expiresAt']?.toString(),
        'remaining_days':
            state['expiresAt']?.toString() == null
                ? null
                : _estimateRemainingDays(state['expiresAt'].toString()),
        'offline_grace_until': state['offlineGraceUntil']?.toString(),
        'next_revalidation_at': state['lastValidationAt']?.toString() == null
            ? null
            : _estimateNextRevalidationAt(
              state['lastValidationAt'].toString(),
              state['licenseType']?.toString() ?? 'permanent',
            ),
        'signature_details': state['failureReason']?.toString(),
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_licenseStatusSnapshotKey, jsonEncode(snapshot));
    } catch (_) {}
  }

  String? _estimateNextRevalidationAt(String lastValidatedAt, String licenseType) {
    final parsed = DateTime.tryParse(lastValidatedAt);
    if (parsed == null) return null;
    final interval =
        licenseType == 'temporary'
            ? const Duration(hours: 24)
            : const Duration(days: 5);
    return parsed.add(interval).toIso8601String();
  }

  int? _estimateRemainingDays(String expiresAt) {
    final expiry = DateTime.tryParse(expiresAt);
    if (expiry == null) return null;
    final remaining = expiry.difference(DateTime.now());
    if (remaining.inSeconds <= 0) return 0;
    return (remaining.inSeconds / Duration.secondsPerDay).ceil();
  }

  static String computeIntegrityHash(Map<String, dynamic> state) {
    final copy = Map<String, dynamic>.from(state)..remove('integrity');
    return sha256.convert(utf8.encode(jsonEncode(copy))).toString();
  }
}
