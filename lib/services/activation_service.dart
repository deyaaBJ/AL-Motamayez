import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:motamayez/constant/constant.dart';
import 'package:motamayez/services/licensing/activation_api_client.dart';
import 'package:motamayez/services/licensing/license_state_manager.dart';
import 'package:motamayez/services/licensing/license_storage.dart';
import 'package:motamayez/services/licensing/license_validator.dart';
import 'package:motamayez/utils/app_logger.dart';

class ActivationException implements Exception {
  final String message;
  final String? storedSignature;
  final String? signatureDetails;

  ActivationException(
    this.message, {
    this.storedSignature,
    this.signatureDetails,
  });

  @override
  String toString() => message;
}

class ActivationService {
  ActivationService({
    http.Client? client,
    LicenseStorage? storage,
    LicenseStateManager? stateManager,
    LicenseValidator? validator,
    ActivationApiClient? apiClient,
  }) : _storage = storage ?? LicenseStorage(),
       _stateManager =
           stateManager ??
           LicenseStateManager(
             storage: storage ?? LicenseStorage(),
             validator:
                 validator ??
                 LicenseValidator(
                   publicKeyPem: AppConstants.rsaPublicKeyPem,
                   normalizeActivationCode: _staticNormalizeActivationCode,
                 ),
             resolveDeviceFingerprint: _resolveHardwareDeviceFingerprint,
           ),
       _apiClient =
           apiClient ??
           ActivationApiClient(
             client: client ?? http.Client(),
             baseUrl: AppConstants.activationBaseUrl,
           );

  final LicenseStorage _storage;
  final LicenseStateManager _stateManager;
  final ActivationApiClient _apiClient;

 static const String _criticalOperationDepthKey = 'license_critical_depth';
  static const String _sessionStartedAtKey = 'license_session_started_at';
  static const String _activationBlockStatusKey = 'activation_block_status';
  static const String _activationBlockRecordedAtKey =
      'activation_block_recorded_at';

  static final RegExp _temporaryActivationPattern = RegExp(
    r'^DAY-?(\d+)$',
    caseSensitive: false,
  );

  static String _staticNormalizeActivationCode(String value) {
    return value.trim().toUpperCase();
  }

  String _normalizeActivationCode(String value) {
    return _staticNormalizeActivationCode(value);
  }

  String _networkErrorMessage(String action) {
    return 'تعذر $action بسبب مشكلة في الاتصال. يرجى التحقق من الإنترنت والمحاولة مرة أخرى.';
  }

  String _normalizeMessage(String message) {
    if (!(message.contains('Ã˜') ||
        message.contains('Ã™') ||
        message.contains('Ãƒ') ||
        message.contains('Ã‚'))) {
      return message;
    }

    try {
      return utf8.decode(latin1.encode(message));
    } catch (_) {
      return message;
    }
  }

  String _messageOrDefault(dynamic value, String fallback) {
    final message = value?.toString().trim();
    if (message == null || message.isEmpty) return fallback;
    return _normalizeMessage(message);
  }

  Map<String, dynamic>? _mapValue(dynamic value) {
    return value is Map<String, dynamic> ? value : null;
  }

  String? _firstTextValue(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;

    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  Map<String, dynamic>? _extractRequestData(Map<String, dynamic> data) {
    final wrappedData = _mapValue(data['data']);
    return _mapValue(data['request']) ??
        _mapValue(data['activationRequest']) ??
        _mapValue(data['activation']) ??
        _mapValue(wrappedData?['request']) ??
        _mapValue(wrappedData?['activationRequest']) ??
        _mapValue(wrappedData?['activation']) ??
        wrappedData;
  }

  String? _extractRequestId(
    Map<String, dynamic> data,
    Map<String, dynamic>? request,
  ) {
    return _firstTextValue(request, ['id', '_id', 'requestId']) ??
        _firstTextValue(data, ['requestId', 'id', '_id']);
  }

  String _extractRequestStatus(
    Map<String, dynamic> data,
    Map<String, dynamic>? request, {
    String fallback = 'pending',
  }) {
    return _firstTextValue(request, ['status', 'requestStatus']) ??
        _firstTextValue(data, ['status', 'requestStatus']) ??
        fallback;
  }

  String? _extractAssignedCode(
    Map<String, dynamic> data,
    Map<String, dynamic>? request,
  ) {
    return _firstTextValue(request, [
          'assignedCode',
          'activationCode',
          'code',
          'licenseCode',
        ]) ??
        _firstTextValue(data, [
          'assignedCode',
          'activationCode',
          'code',
          'licenseCode',
        ]);
  }

  String? _extractRejectionReason(
    Map<String, dynamic> data,
    Map<String, dynamic>? request,
  ) {
    return _firstTextValue(request, [
          'rejectionReason',
          'rejectReason',
          'reason',
        ]) ??
        _firstTextValue(data, ['rejectionReason', 'rejectReason', 'reason']);
  }

  Map<String, dynamic>? _extractLicensePayload(Map<String, dynamic> data) {
    final wrappedData = _mapValue(data['data']);
    return _mapValue(data['license']) ??
        _mapValue(data['activation']) ??
        _mapValue(wrappedData?['license']) ??
        _mapValue(wrappedData?['activation']) ??
        wrappedData;
  }

  Map<String, dynamic>? _extractActivationResponse(Map<String, dynamic> data) {
    final wrappedData = _mapValue(data['data']);
    return _mapValue(data['activation']) ??
        _mapValue(data['license']) ??
        _mapValue(wrappedData?['activation']) ??
        _mapValue(wrappedData?['license']) ??
        wrappedData ??
        data;
  }

  Map<String, dynamic>? _extractActivationLicense(Map<String, dynamic> data) {
    final wrappedData = _mapValue(data['data']);
    return _mapValue(data['license']) ??
        _mapValue(data['activation']) ??
        _mapValue(wrappedData?['license']) ??
        _mapValue(wrappedData?['activation']) ??
        _extractActivationResponse(data);
  }

  bool _isActiveServerStatus(String? status) {
    final normalized = status?.trim().toLowerCase();
    return normalized == 'active' ||
        normalized == 'activated' ||
        normalized == 'valid' ||
        normalized == 'approved' ||
        normalized == 'completed' ||
        normalized == 'already_activated';
  }

  bool _isServerActivated(
    Map<String, dynamic> data,
    Map<String, dynamic>? responseData,
    String? status,
  ) {
    final explicitActivated = responseData?['activated'] ?? data['activated'];
    if (explicitActivated is bool) return explicitActivated;

    final explicitValid = responseData?['valid'] ?? data['valid'];
    if (explicitValid is bool) return explicitValid;

    return _isActiveServerStatus(status);
  }

  bool _shouldClearLocalActivationForServerStatus(String? status) {
    final normalized = status?.trim().toLowerCase();
    return normalized == 'not_activated' ||
        normalized == 'inactive' ||
        normalized == 'deactivated' ||
        normalized == 'disabled' ||
        normalized == 'revoked' ||
        normalized == 'rejected' ||
        normalized == 'expired' ||
        normalized == 'device_changed' ||
        normalized == 'multiple_devices_detected' ||
        normalized == 'requires_manual_review';
  }

  Future<Map<String, dynamic>> _saveServerActivationResponse({
    required Map<String, dynamic> data,
    required String deviceId,
    required String deviceFingerprint,
  }) async {
    final responseData = _mapValue(data['data']);
    final payload = _extractLicensePayload(data);
    final license =
        _mapValue(responseData?['license']) ??
        _mapValue(data['license']) ??
        _mapValue(payload?['license']) ??
        payload;
    final claims =
        _mapValue(responseData?['claims']) ??
        _mapValue(data['claims']) ??
        _mapValue(payload?['claims']) ??
        license;
    final tokenHeader =
        _mapValue(responseData?['tokenHeader']) ??
        _mapValue(data['tokenHeader']) ??
        _mapValue(payload?['tokenHeader']);
    final token =
        responseData?['token']?.toString() ??
        data['token']?.toString() ??
        payload?['token']?.toString() ??
        responseData?['licenseToken']?.toString() ??
        data['licenseToken']?.toString() ??
        payload?['licenseToken']?.toString();
    final signature =
        responseData?['signature']?.toString() ??
        data['signature']?.toString() ??
        payload?['signature']?.toString();

    if (token != null &&
        token.isNotEmpty &&
        license != null &&
        license.isNotEmpty &&
        claims != null &&
        claims.isNotEmpty) {
      await _saveActivatedLicense(
        licenseToken: token,
        deviceId: deviceId,
        deviceFingerprint: deviceFingerprint,
        license: license,
        claims: claims,
        tokenHeader: tokenHeader,
        requestId: _extractRequestId(data, _extractRequestData(data)),
      );
      await _storage.clearPendingRequest();
      return {
        'success': true,
        'activated': true,
        'status': 'valid',
        'message': _messageOrDefault(data['message'], 'Device activated'),
      };
    }

    if (signature != null &&
        signature.isNotEmpty &&
        payload != null &&
        payload.isNotEmpty) {
      await _completeLocalActivation(
        activationData: payload,
        signature: signature,
        token: token,
      );
      return {
        'success': true,
        'activated': true,
        'status': 'valid',
        'message': _messageOrDefault(data['message'], 'Device activated'),
      };
    }

    return {
      'success': false,
      'activated': false,
      'status': 'missing_license_payload',
      'message': _messageOrDefault(
        data['message'],
        'Server says this device is activated, but no license payload was received.',
      ),
    };
  }

  static String? _normalizeHardwareValue(String? value) {
    if (value == null) return null;
    final normalized =
        value.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();
    if (normalized.isEmpty) return null;
    if (normalized == 'TO BE FILLED BY O.E.M.') return null;
    if (normalized == 'DEFAULT STRING') return null;
    if (normalized == 'SYSTEM SERIAL NUMBER') return null;
    return normalized;
  }

  static Future<String?> _runPowerShellValue(String command) async {
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        command,
      ]);
      if (result.exitCode != 0) return null;
      return _normalizeHardwareValue(result.stdout?.toString());
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _getWindowsDeviceFingerprint() async {
    final values = await Future.wait([
      _runPowerShellValue(
        r"(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Cryptography').MachineGuid",
      ),
      _runPowerShellValue(r"(Get-CimInstance Win32_BIOS).SerialNumber"),
      _runPowerShellValue(r"(Get-CimInstance Win32_BaseBoard).SerialNumber"),
    ]);

    final parts =
        values.whereType<String>().where((value) => value.isNotEmpty).toList();
    if (parts.isEmpty) return null;

    return sha256.convert(utf8.encode(parts.join('|'))).toString();
  }

  static Future<String?> _resolveHardwareDeviceFingerprint() async {
    if (Platform.isWindows) {
      return _getWindowsDeviceFingerprint();
    }
    return null;
  }

  Future<String?> getDeviceId() {
    return _resolveHardwareDeviceFingerprint();
  }

  Future<String?> getDeviceFingerprint() {
    return _resolveHardwareDeviceFingerprint();
  }

 Future<Map<String, dynamic>?> _readSavedLicenseState() {
    return _storage.readLicenseCache();
  }

  Future<String?> _readActivationBlockStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final status = prefs.getString(_activationBlockStatusKey)?.trim();
    return status == null || status.isEmpty ? null : status;
  }

  Future<void> _saveActivationBlockStatus(String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activationBlockStatusKey, status);
    await prefs.setString(
      _activationBlockRecordedAtKey,
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> _clearActivationBlockStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activationBlockStatusKey);
    await prefs.remove(_activationBlockRecordedAtKey);
  }

 Map<String, dynamic>? _blockedActivationInfo(String? status) {
    if (!_shouldClearLocalActivationForServerStatus(status)) return null;
    return {
      'has_activation': false,
      'status': 'not_activated',
      'signature_details': status,
    };
  }

  Future<Map<String, dynamic>> getInitialActivationInfo() async {
    try {
      // أي حظر/رفض مسجّل من السيرفر يطغى على الكاش المحلي من أول خطوة،
      // حتى لو الكاش المحلي بيقول "valid".
      final blockStatus = await _readActivationBlockStatus();
      if (blockStatus != null) {
        final blocked = _blockedActivationInfo(blockStatus);
        if (blocked != null) {
          return {
            ...blocked,
            'activation_type': 'permanent',
          };
        }
      }

      final savedState = await _storage.readLicenseCache();
      if (savedState == null) {
        return {'has_activation': false, 'activation_type': 'permanent'};
      }

      final result = await _evaluateLicenseState();
      final cache = result['cache'] as Map<String, dynamic>?;

      if (cache == null) {
        return {'has_activation': false, 'activation_type': 'permanent'};
      }

      final expiresAt = cache['expiresAt']?.toString();
      final remainingDays =
          expiresAt == null || expiresAt.isEmpty
              ? null
              : _calculateRemainingDays(expiresAt);

      return {
        'has_activation': true,
        'license_id': cache['licenseId'],
        'activation_type': cache['licenseType'] ?? 'permanent',
        'expires_at': expiresAt,
        'remaining_days': remainingDays,
      };
    } catch (_) {
      return {'has_activation': false, 'activation_type': 'permanent'};
    }
  }

  Future<Map<String, dynamic>> _activationInfoFromLocalEvaluation() async {
    final result = await _evaluateLicenseState();
    final status = result['status']?.toString() ?? 'not_activated';
    final cache = result['cache'] as Map<String, dynamic>?;
    final evaluation = result['evaluation'] as LicenseEvaluationResult?;

    if (status == 'not_activated' || cache == null) {
      return {'has_activation': false, 'status': 'not_activated'};
    }

    final expiresAt = cache['expiresAt']?.toString();
    final remainingDays =
        expiresAt == null || expiresAt.isEmpty
            ? null
            : _calculateRemainingDays(expiresAt);

    return {
      'has_activation': true,
      'status': evaluation?.publicStatus ?? status,
      'license_id': cache['licenseId'],
      'activation_type': cache['licenseType'] ?? 'permanent',
      'expires_at': expiresAt,
      'remaining_days': remainingDays,
      'offline_grace_until':
          evaluation?.offlineGraceUntil?.toIso8601String() ??
          cache['offlineGraceUntil'],
      'next_revalidation_at': evaluation?.nextRevalidationAt?.toIso8601String(),
      'signature_details':
          cache['failureReason']?.toString() ?? evaluation?.reason,
      'verification_status': evaluation?.verificationStatus.name ?? status,
      'security_trust': evaluation?.trustScore?.toPublicMap(),
      'can_use_current_session': evaluation?.canUseCurrentSession == true,
      'allow_login': evaluation?.allowLogin == true,
    };
  }

  Future<void> _saveActivatedLicense({
    required String licenseToken,
    required String deviceId,
    required String deviceFingerprint,
    required Map<String, dynamic> license,
    required Map<String, dynamic> claims,
    Map<String, dynamic>? tokenHeader,
    String? requestId,
  }) async {
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final licenseType =
        license['type']?.toString() ??
        claims['type']?.toString() ??
        'permanent';
    final licenseId =
        license['licenseId']?.toString() ??
        license['id']?.toString() ??
        claims['licenseId']?.toString();
    final expiresAt =
        license['expiresAt']?.toString() ?? claims['expiresAt']?.toString();
    final activatedAt =
        license['activatedAt']?.toString() ??
        claims['activatedAt']?.toString() ??
        nowIso;
    final envelope = {
      'license': license,
      'token': licenseToken,
      if (tokenHeader != null) 'tokenHeader': tokenHeader,
      'claims': claims,
    };
    final activationRequestId =
        requestId ??
        license['requestId']?.toString() ??
        license['activationRequestId']?.toString() ??
        claims['requestId']?.toString() ??
        claims['activationRequestId']?.toString();

    await _storage.saveLicenseCache({
      'licenseBlob': jsonEncode(envelope),
      'licenseStatus': 'valid',
      'licenseToken': licenseToken,
      'deviceId': deviceId,
      'deviceFingerprint': deviceFingerprint,
      'deviceHash': deviceFingerprint,
      'license': license,
      'claims': claims,
      if (tokenHeader != null) 'tokenHeader': tokenHeader,
      'licenseSource': 'server_token',
      'licenseType': licenseType,
      if (licenseId != null && licenseId.isNotEmpty) 'licenseId': licenseId,
      if (activationRequestId != null && activationRequestId.isNotEmpty)
        'activationRequestId': activationRequestId,
      if (expiresAt != null && expiresAt.isNotEmpty) 'expiresAt': expiresAt,
      'activatedAt': activatedAt,
      'offlineGraceUntil':
          _stateManager
              .computeOfflineGraceUntil(now: now, licenseType: licenseType)
              .toIso8601String(),
      'lastValidationTime': nowIso,
      'lastValidationAt': nowIso,
      'lastKnownServerTime': nowIso,
      'serverStatus':
          license['status']?.toString() ?? claims['status']?.toString(),
      'failureReason': null,
      'tamperDetected': false,
    });

    // تفعيل ناجح فعليًا => أي حظر/رفض قديم محفوظ يروح من هنا.
    await _clearActivationBlockStatus();
  }
  String? _licenseTokenFromCache(Map<String, dynamic>? cache) {
    final token = cache?['licenseToken']?.toString().trim();
    return token == null || token.isEmpty ? null : token;
  }

  String? _activationRequestIdFromCache(Map<String, dynamic>? cache) {
    if (cache == null) return null;

    final license = _mapValue(cache['license']);
    final claims = _mapValue(cache['claims']);
    final requestId =
        _firstTextValue(cache, ['activationRequestId', 'requestId']) ??
        _firstTextValue(license, ['activationRequestId', 'requestId']) ??
        _firstTextValue(claims, ['activationRequestId', 'requestId']);

    return requestId == null || requestId.isEmpty ? null : requestId;
  }

  Future<Map<String, dynamic>?> _rejectIfSavedRequestIsInactive({
    required Map<String, dynamic>? savedState,
    required String deviceId,
  }) async {
    final requestId = _activationRequestIdFromCache(savedState);
    if (requestId == null) return null;

    final response = await _apiClient.getRequestStatus(
      requestId: requestId,
      deviceId: deviceId,
    );
    final statusCode = response['statusCode'] as int;
    final data = response['body'] as Map<String, dynamic>;
    if (statusCode == 404) return null;

    final request = _extractRequestData(data);
    final status = _extractRequestStatus(data, request);
    if (_shouldClearLocalActivationForServerStatus(status)) {
      await clearActivation();
      return {
        'has_activation': false,
        'status': 'not_activated',
        'signature_details': status,
      };
    }

    return null;
  }

  Future<Map<String, dynamic>?> _repairServerTokenCache(
    Map<String, dynamic>? cache,
  ) async {
    if (cache == null) return null;

    final token = _licenseTokenFromCache(cache);
    final blob = cache['licenseBlob']?.toString().trim();
    final license = _mapValue(cache['license']);
    final claims = _mapValue(cache['claims']);
    if (token == null ||
        (blob != null && blob.isNotEmpty) ||
        license == null ||
        claims == null) {
      return cache;
    }

    final repaired = Map<String, dynamic>.from(cache);
    final licenseType =
        license['type']?.toString() ??
        claims['type']?.toString() ??
        'permanent';
    final licenseId =
        license['licenseId']?.toString() ??
        license['id']?.toString() ??
        claims['licenseId']?.toString();
    final expiresAt =
        license['expiresAt']?.toString() ?? claims['expiresAt']?.toString();
    final now = DateTime.now();

    repaired['licenseBlob'] = jsonEncode({
      'license': license,
      'token': token,
      if (cache['tokenHeader'] != null) 'tokenHeader': cache['tokenHeader'],
      'claims': claims,
    });
    repaired['licenseStatus'] = 'valid';
    repaired['licenseSource'] = 'server_token';
    repaired['licenseType'] = licenseType;
    repaired['failureReason'] = null;
    repaired['tamperDetected'] = false;
    repaired['offlineGraceUntil'] =
        repaired['offlineGraceUntil'] ??
        _stateManager
            .computeOfflineGraceUntil(now: now, licenseType: licenseType)
            .toIso8601String();
    if (licenseId != null && licenseId.isNotEmpty) {
      repaired['licenseId'] = licenseId;
    }
    if (expiresAt != null && expiresAt.isNotEmpty) {
      repaired['expiresAt'] = expiresAt;
    }
    repaired['activatedAt'] =
        repaired['activatedAt'] ??
        license['activatedAt']?.toString() ??
        claims['activatedAt']?.toString() ??
        now.toIso8601String();

    await _storage.saveLicenseCache(repaired);
    return repaired;
  }

  Map<String, dynamic> _buildLicenseEnvelope({
    required Map<String, dynamic> activationData,
    required String signature,
    String? token,
  }) {
    final license = _extractActivationLicense(activationData) ?? activationData;
    return {
      'license': {
        'deviceId':
            license['deviceId']?.toString() ?? activationData['deviceId']?.toString(),
        'activationCode':
            license['activationCode']?.toString() ??
            license['code']?.toString() ??
            activationData['activationCode']?.toString() ??
            activationData['code']?.toString(),
        'expiresAt':
            license['expiresAt']?.toString() ??
            activationData['expiresAt']?.toString(),
        'activatedAt':
            license['activatedAt']?.toString() ??
            activationData['activatedAt']?.toString(),
        'licenseId':
            license['licenseId']?.toString() ??
            license['id']?.toString() ??
            activationData['licenseId']?.toString() ??
            activationData['id']?.toString(),
        'status': license['status']?.toString() ?? activationData['status']?.toString(),
        'type': license['type']?.toString() ?? activationData['type']?.toString(),
      },
      'signature': signature,
      if (token != null && token.isNotEmpty) 'token': token,
    };
  }

  String _classifyLicenseType(Map<String, dynamic> activationData) {
    final code =
        activationData['activationCode']?.toString() ??
        activationData['code']?.toString() ??
        '';
    return _temporaryActivationPattern.hasMatch(code)
        ? 'temporary'
        : 'permanent';
  }

  int _calculateRemainingDays(String expiresAt) {
    final expiry = DateTime.tryParse(expiresAt);
    if (expiry == null) return 0;

    final remaining = expiry.difference(DateTime.now());
    if (remaining.inSeconds <= 0) return 0;

    return (remaining.inSeconds / Duration.secondsPerDay).ceil();
  }

  Future<void> _persistCache(Map<String, dynamic> cache) {
    return _stateManager.persistLicenseCache(cache);
  }

  Future<void> _migrateLegacyStateIfNeeded() async {
    final existing = await _storage.readLicenseCache();
    if (existing != null) return;

    final legacy = await _storage.readLegacyActivationState();
    if (legacy == null) return;

    final migrated = <String, dynamic>{
      'licenseBlob': null,
      'licenseStatus': 'needs_revalidation',
      'failureReason': 'legacy_cache_requires_signed_token_refresh',
      'licenseType': legacy['activation_type']?.toString() ?? 'permanent',
      'licenseId': legacy['license_id']?.toString(),
      'deviceHash': legacy['device_id_snapshot']?.toString(),
      'lastValidationAt': legacy['last_verified_at']?.toString(),
      'offlineGraceUntil':
          legacy['last_verified_at']?.toString() == null
              ? null
              : _stateManager
                  .computeOfflineGraceUntil(
                    now:
                        DateTime.tryParse(
                          legacy['last_verified_at']?.toString() ?? '',
                        ) ??
                        DateTime.now(),
                    licenseType:
                        legacy['activation_type']?.toString() ?? 'permanent',
                  )
                  .toIso8601String(),
      'lastKnownServerTime': legacy['last_verified_at']?.toString(),
      'expiresAt': legacy['expires_at']?.toString(),
      'activatedAt': legacy['activated_at']?.toString(),
      'migratedFromLegacyCache': true,
    };

    await _persistCache(migrated);
    await _storage.clearLegacySensitiveState();
  }

 Future<void> _completeLocalActivation({
    required Map<String, dynamic> activationData,
    required String signature,
    String? token,
  }) async {
    final now = DateTime.now();
    final deviceId = await getDeviceId();
    if (deviceId == null || deviceId.isEmpty) {
      throw ActivationException('device_fingerprint_unavailable');
    }
    final type = _classifyLicenseType(activationData);
    final envelope = _buildLicenseEnvelope(
      activationData: activationData,
      signature: signature,
      token: token,
    );

    final state = <String, dynamic>{
      // Store only the signed blob + minimal metadata needed for offline policy.
      'licenseBlob': jsonEncode(envelope),
      'licenseStatus': 'valid',
      'failureReason': null,
      'licenseType': type,
      'licenseId':
          activationData['licenseId']?.toString() ??
          activationData['id']?.toString(),
      'deviceHash': deviceId,
      'lastValidationAt': now.toIso8601String(),
      'offlineGraceUntil':
          _stateManager
              .computeOfflineGraceUntil(now: now, licenseType: type)
              .toIso8601String(),
      'lastKnownServerTime': now.toIso8601String(),
      'expiresAt': activationData['expiresAt']?.toString(),
      'activatedAt':
          activationData['activatedAt']?.toString() ?? now.toIso8601String(),
      'serverStatus': activationData['status']?.toString(),
      if (token != null && token.isNotEmpty) 'licenseToken': token,
      'tamperDetected': false,
    };

    await _persistCache(state);
    await _storage.clearLegacySensitiveState();
    await _storage.clearPendingRequest();
    await _clearActivationBlockStatus();
  }

 Future<void> _completeServerTokenActivation({
    required Map<String, dynamic> activationData,
    required String token,
  }) async {
    final now = DateTime.now();
    final deviceId = await getDeviceId();
    if (deviceId == null || deviceId.isEmpty) {
      throw ActivationException('device_fingerprint_unavailable');
    }

    final serverType = activationData['type']?.toString().trim();
    final type =
        serverType != null && serverType.isNotEmpty
            ? serverType
            : _classifyLicenseType(activationData);
    final envelope = _buildLicenseEnvelope(
      activationData: activationData,
      signature: '',
      token: token,
    );

    final state = <String, dynamic>{
      'licenseBlob': jsonEncode(envelope),
      'licenseStatus': 'valid',
      'failureReason': null,
      'licenseSource': 'server_token',
      'licenseType': type,
      'licenseId':
          activationData['licenseId']?.toString() ??
          activationData['id']?.toString(),
      'deviceHash': deviceId,
      'lastValidationAt': now.toIso8601String(),
      'offlineGraceUntil':
          _stateManager
              .computeOfflineGraceUntil(now: now, licenseType: type)
              .toIso8601String(),
      'lastKnownServerTime': now.toIso8601String(),
      'expiresAt': activationData['expiresAt']?.toString(),
      'activatedAt':
          activationData['activatedAt']?.toString() ?? now.toIso8601String(),
      'serverStatus': activationData['status']?.toString(),
      'licenseToken': token,
      'tamperDetected': false,
    };

    await _persistCache(state);
    await _storage.clearLegacySensitiveState();
    await _storage.clearPendingRequest();
    await _clearActivationBlockStatus();
  }


  Future<Map<String, dynamic>> _evaluateLicenseState() async {
    await _migrateLegacyStateIfNeeded();
    final evaluation = await _stateManager.evaluate();
    return {
      'has_activation':
          evaluation.verificationStatus !=
          LicenseVerificationStatus.notActivated,
      'status': evaluation.publicStatus,
      'cache': evaluation.cache,
      'evaluation': evaluation,
    };
  }
Future<Map<String, dynamic>> checkDeviceActivationOnServer() async {
    try {
      final deviceId = await getDeviceId();
      final deviceFingerprint = await getDeviceFingerprint();
      if (deviceId == null ||
          deviceId.isEmpty ||
          deviceFingerprint == null ||
          deviceFingerprint.isEmpty) {
        return {
          'success': false,
          'activated': false,
          'status': 'needs_revalidation',
          'message': 'Unable to read device fingerprint.',
        };
      }

      final response = await _apiClient.getDeviceActivationStatus(
        deviceId: deviceId,
        deviceFingerprint: deviceFingerprint,
      );
      final statusCode = response['statusCode'] as int;
      final data = response['body'] as Map<String, dynamic>;
      final responseData = _mapValue(data['data']);
      final request = _extractRequestData(data);
      final status =
          _firstTextValue(responseData, ['status', 'licenseStatus']) ??
          _extractRequestStatus(data, request, fallback: 'not_activated');
      final activated = _isServerActivated(data, responseData, status);

      if (statusCode == 404) {
        return {
          'success': false,
          'activated': false,
          'status': 'endpoint_not_found',
          'message': 'Device activation status endpoint was not found.',
        };
      }

      if (statusCode != 200 || data['success'] == false) {
        return {
          'success': false,
          'activated': false,
          'status': status,
          'message': _messageOrDefault(
            data['message'],
            'Device activation status check failed.',
          ),
        };
      }

      if (!activated) {
        if (_shouldClearLocalActivationForServerStatus(status)) {
          await clearActivation();
          // السيرفر هو مصدر الحقيقة هنا: سجّل الرفض/الحظر بشكل صريح
          // بدل الاعتماد على أي كاش محلي قديم قد يقول إنه مفعّل.
          await _saveActivationBlockStatus(status);
        }

        return {
          'success': true,
          'activated': false,
          'status': status,
          'message': _messageOrDefault(
            data['message'],
            'Device is not active.',
          ),
        };
      }

      // السيرفر أكّد إن الجهاز مفعّل فعليًا، فأي حظر قديم محفوظ يصير لاغيًا.
      await _clearActivationBlockStatus();

      final saved = await _saveServerActivationResponse(
        data: data,
        deviceId: deviceId,
        deviceFingerprint: deviceFingerprint,
      );
      if (saved['success'] == true) {
        return saved;
      }

      final requestId = _extractRequestId(data, request);
      final assignedCode = _extractAssignedCode(data, request);
      if (requestId != null && requestId.isNotEmpty) {
        await _storage.savePendingRequest(
          requestId: requestId,
          status: status,
          assignedCode: assignedCode,
        );
      }

      return {
        ...saved,
        'requestId': requestId,
        'assignedCode': assignedCode,
        'status': status,
      };
    } catch (error, stackTrace) {
      if (ActivationApiClient.isConnectivityError(error)) {
        return {
          'success': false,
          'activated': false,
          'status': 'offline',
          'message': _networkErrorMessage('checking device activation'),
        };
      }

      appLog(
        'Device activation status check failed.',
        name: 'ActivationService',
        error: error,
        stackTrace: stackTrace,
      );
      return {
        'success': false,
        'activated': false,
        'status': 'error',
        'message': 'Unable to check device activation status.',
      };
    }
  }

  Future<Map<String, dynamic>?> _rejectIfServerDeviceIsInactive({
    required String deviceId,
    required String deviceFingerprint,
  }) async {
    final response = await _apiClient.getDeviceActivationStatus(
      deviceId: deviceId,
      deviceFingerprint: deviceFingerprint,
    );
    final statusCode = response['statusCode'] as int;
    final data = response['body'] as Map<String, dynamic>;
    final responseData = _mapValue(data['data']);
    final request = _extractRequestData(data);
    final status =
        _firstTextValue(responseData, ['status', 'licenseStatus']) ??
        _extractRequestStatus(data, request, fallback: 'not_activated');
    final activated = _isServerActivated(data, responseData, status);

    if (statusCode == 404) return null;

    if (!activated && _shouldClearLocalActivationForServerStatus(status)) {
      await clearActivation();
      return {
        'has_activation': false,
        'status': 'not_activated',
        'signature_details': status,
      };
    }

    if (statusCode != 200 || data['success'] == false || !activated) {
      return null;
    }

    await _saveServerActivationResponse(
      data: data,
      deviceId: deviceId,
      deviceFingerprint: deviceFingerprint,
    );
    return null;
  }

  Future<Map<String, dynamic>> createActivationRequest() async {
    try {
      final deviceId = await getDeviceId();
      if (deviceId == null || deviceId.isEmpty) {
        return {
          'success': false,
          'status': 'needs_revalidation',
          'message':
              'تعذر قراءة بصمة الجهاز. يلزم التحقق قبل إرسال طلب التفعيل.',
        };
      }
      final response = await _apiClient.createActivationRequest(
        deviceId: deviceId,
      );
      final statusCode = response['statusCode'] as int;
      final data = response['body'] as Map<String, dynamic>;

      if (data['success'] != true) {
        return {
          'success': false,
          'message': _messageOrDefault(data['message'], 'Activation failed'),
        };
      }

      if (statusCode != 200 && statusCode != 201) {
        return {
          'success': false,
          'message': _messageOrDefault(
            data['message'],
            'فشل إرسال طلب التفعيل',
          ),
        };
      }

      final responseData = _mapValue(data['data']);
      final requestId = responseData?['requestId']?.toString();
      final status = responseData?['status']?.toString() ?? 'pending';

      if (requestId == null || requestId.isEmpty) {
        return {
          'success': false,
          'message': 'لم يتم استلام رقم الطلب من الخادم',
        };
      }

      await _storage.savePendingRequest(requestId: requestId, status: status);
      // طلب جديد => امسح أي حظر قديم حتى ما يبقى التطبيق محجوب بسبب رفض سابق.
      await _clearActivationBlockStatus();

      return {
        'success': true,
        'status': status,
        'requestId': requestId,
        'deviceId': responseData?['deviceId']?.toString() ?? deviceId,
        'createdAt': responseData?['createdAt']?.toString(),
        'message': _messageOrDefault(data['message'], 'تم إرسال طلب التفعيل'),
      };
    } catch (error, stackTrace) {
      if (ActivationApiClient.isConnectivityError(error)) {
        return {
          'success': false,
          'message': _networkErrorMessage('إرسال طلب التفعيل'),
        };
      }

      appLog(
        'Activation request failed.',
        name: 'ActivationService',
        error: error,
        stackTrace: stackTrace,
      );
      return {
        'success': false,
        'message': 'تعذر إرسال طلب التفعيل حاليًا. يرجى المحاولة مرة أخرى.',
      };
    }
  }
  Future<Map<String, dynamic>> getRequestStatus({String? requestId}) async {
    try {
      final savedRequest = await _storage.getSavedPendingRequest();
      final effectiveRequestId =
          requestId ?? savedRequest?['requestId']?.toString();
      if (effectiveRequestId == null || effectiveRequestId.isEmpty) {
        return {'success': false, 'message': 'لا يوجد طلب تفعيل محفوظ'};
      }

      final deviceId = await getDeviceId();
      if (deviceId == null || deviceId.isEmpty) {
        return {
          'success': false,
          'status': 'needs_revalidation',
          'message':
              'تعذر قراءة بصمة الجهاز. يلزم إعادة التحقق قبل متابعة حالة التفعيل.',
        };
      }
      final response = await _apiClient.getRequestStatus(
        requestId: effectiveRequestId,
        deviceId: deviceId,
      );
      final statusCode = response['statusCode'] as int;
      final data = response['body'] as Map<String, dynamic>;

      if (statusCode != 200) {
        return {
          'success': false,
          'message': _messageOrDefault(
            data['message'],
            'فشل التحقق من حالة الطلب',
          ),
        };
      }

      final request = _extractRequestData(data);
      final legacyStatus = _extractRequestStatus(data, request);
      final assignedCode = _extractAssignedCode(data, request);
      final legacyRejectionReason = _extractRejectionReason(data, request);
      if (_shouldClearLocalActivationForServerStatus(legacyStatus)) {
        await _storage.clearPendingRequest();
      } else {
        await _storage.savePendingRequest(
          requestId: effectiveRequestId,
          status: legacyStatus,
          assignedCode: assignedCode,
        );
      }

      return {
        'success': true,
        'requestId': effectiveRequestId,
        'status': legacyStatus,
        'assignedCode': assignedCode,
        'rejectionReason': legacyRejectionReason,
        'message': _messageOrDefault(data['message'], 'تم تحديث حالة الطلب'),
      };
    } catch (error, stackTrace) {
      if (ActivationApiClient.isConnectivityError(error)) {
        return {
          'success': false,
          'message': _networkErrorMessage('التحقق من حالة طلب التفعيل'),
        };
      }

      appLog(
        'Activation status check failed.',
        name: 'ActivationService',
        error: error,
        stackTrace: stackTrace,
      );
      return {
        'success': false,
        'message': 'تعذر التحقق من حالة الطلب حاليًا. يرجى المحاولة مرة أخرى.',
      };
    }
  }

  Future<Map<String, dynamic>> activateWithRequest({
    required String activationCode,
    String? requestId,
  }) async {
    try {
      final normalizedCode = _normalizeActivationCode(activationCode);
      final savedRequest = await _storage.getSavedPendingRequest();
      final effectiveRequestId =
          requestId ?? savedRequest?['requestId']?.toString();
      if (effectiveRequestId == null || effectiveRequestId.isEmpty) {
        return {'success': false, 'message': 'Missing activation request ID.'};
      }

      final deviceId = await getDeviceId();
      if (deviceId == null || deviceId.isEmpty) {
        return {
          'success': false,
          'status': 'needs_revalidation',
          'message':
              'تعذر قراءة بصمة الجهاز. لا يمكن إكمال التفعيل قبل إعادة التحقق.',
        };
      }
      final response = await _apiClient.activate(
        activationCode: normalizedCode,
        deviceId: deviceId,
        deviceFingerprint: deviceId,
        requestId: effectiveRequestId,
      );
      final statusCode = response['statusCode'] as int;
      final data = response['body'] as Map<String, dynamic>;
      final apiSuccess = data['success'] == true;

      if (data['success'] == false) {
        return {
          'success': false,
          'message': _messageOrDefault(data['message'], 'Activation failed'),
        };
      }

      if (statusCode != 200 && statusCode != 201 && !apiSuccess) {
        return {
          'success': false,
          'message': _messageOrDefault(data['message'], 'فشل تنفيذ التفعيل'),
        };
      }

      final activation = _extractActivationResponse(data);
      final licenseData = _extractActivationLicense(data) ?? activation;
      final responseData = _mapValue(data['data']);
      final activationMap = activation ?? <String, dynamic>{};
      final licenseMap = licenseData ?? <String, dynamic>{};
      final signature =
          data['signature']?.toString() ??
          responseData?['signature']?.toString() ??
          activation?['signature']?.toString();
      final token =
          data['token']?.toString() ??
          responseData?['token']?.toString() ??
          activation?['token']?.toString();

      final license =
          _mapValue(data['license']) ??
          _mapValue(data['activation']) ??
          _mapValue(responseData?['license']) ??
          _mapValue(responseData?['activation']) ??
          licenseData ??
          activation;
      final claims =
          _mapValue(data['claims']) ??
          _mapValue(responseData?['claims']) ??
          _mapValue(activation?['claims']) ??
          license;

      if (activation == null || activation.isEmpty) {
        return {
          'success': false,
          'message': 'تعذر استلام بيانات الترخيص من الخادم.',
        };
      }

      // التحقق من البيانات إذا كانت موجودة
      final responseDeviceId =
          licenseMap['deviceId']?.toString() ??
          activationMap['deviceId']?.toString();
      if (responseDeviceId != null &&
          responseDeviceId.isNotEmpty &&
          responseDeviceId != deviceId) {
        return {
          'success': false,
          'message': 'بيانات التفعيل المستلمة لا تطابق هذا الجهاز.',
        };
      }

      final signedCode =
          licenseMap['activationCode']?.toString() ??
          licenseMap['code']?.toString() ??
          activationMap['activationCode']?.toString() ??
          activationMap['code']?.toString();
      if (signedCode != null &&
          _normalizeActivationCode(signedCode) != normalizedCode) {
        return {
          'success': false,
          'message': 'كود التفعيل المستلم من السيرفر غير مطابق.',
        };
      }

      // إذا كانت هناك signature، تحقق من التوقيع الرقمي
      if (signature != null && signature.isNotEmpty) {
        final validation = await _stateManager.validateLicenseEnvelope(
          licenseEnvelope: _buildLicenseEnvelope(
            activationData: activation,
            signature: signature,
            token: token,
          ),
          now: DateTime.now(),
        );

        if (!validation.isValid) {
          return {
            'success': false,
            'message': 'تعذر التحقق من التوقيع الرقمي للترخيص.',
          };
        }
      }

      // حفظ البيانات محليا
      try {
        if (signature != null && signature.isNotEmpty) {
          await _completeLocalActivation(
            activationData: activation,
            signature: signature,
            token: token,
          );
        } else if (token != null && token.isNotEmpty) {
          await _completeServerTokenActivation(
            activationData: activation,
            token: token,
          );
        } else {
          final now = DateTime.now();
          final type =
              activation['type']?.toString() ?? _classifyLicenseType(activation);
          final envelope = _buildLicenseEnvelope(
            activationData: activation,
            signature: '',
          );
          final state = <String, dynamic>{
            'licenseBlob': jsonEncode(envelope),
            'licenseStatus': 'valid',
            'failureReason': null,
            'licenseType': type,
            'licenseId':
                activation['licenseId']?.toString() ??
                activation['id']?.toString(),
            'deviceHash': deviceId,
            'lastValidationAt': now.toIso8601String(),
            'offlineGraceUntil':
                _stateManager
                    .computeOfflineGraceUntil(now: now, licenseType: type)
                    .toIso8601String(),
            'lastKnownServerTime': now.toIso8601String(),
            'expiresAt': activation['expiresAt']?.toString(),
            'activatedAt':
                activation['activatedAt']?.toString() ?? now.toIso8601String(),
            'serverStatus': activation['status']?.toString(),
            'tamperDetected': false,
          };
          await _persistCache(state);
          await _storage.clearLegacySensitiveState();
          await _storage.clearPendingRequest();
          await _clearActivationBlockStatus();
        }
      } catch (saveError, saveStackTrace) {
        appLog(
          'Activation succeeded on server but local persistence failed.',
          name: 'ActivationService',
          error: saveError,
          stackTrace: saveStackTrace,
        );
      }

      return {
        'success': true,
        'message': _messageOrDefault(data['message'], 'تم التفعيل بنجاح'),
      };
    } catch (error, stackTrace) {
      if (ActivationApiClient.isConnectivityError(error)) {
        return {
          'success': false,
          'message': _networkErrorMessage('تنفيذ التفعيل'),
        };
      }

      appLog(
        'Activation failed.',
        name: 'ActivationService',
        error: error,
        stackTrace: stackTrace,
      );
      return {
        'success': false,
        'message': 'تعذر تنفيذ التفعيل حاليًا. يرجى المحاولة مرة أخرى.',
      };
    }
  }

  Future<bool> activate(String activationCode) async {
    final result = await activateWithRequest(activationCode: activationCode);
    return result['success'] == true;
  }

  Future<bool> isActivated() async {
    final info = await getActivationInfo();
    final status = info['status']?.toString();
    return status == 'valid' || status == 'grace_period';
  }

  Future<bool> checkActivationSilently() async {
    try {
      return await isActivated();
    } catch (_) {
      return false;
    }
  }

  Future<void> clearActivation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _storage.clearLicenseCache();
      await _storage.clearLegacySensitiveState();
      await _storage.clearPendingRequest();
      await prefs.remove(_criticalOperationDepthKey);
      await prefs.remove(_sessionStartedAtKey);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getActivationInfo({
    bool forceServerValidation = false,
  }) async {
    Map<String, dynamic>? savedState;
    try {
      // فحص الحظر أولاً: لو السيرفر سبق وقال "مرفوض/غير مفعّل" بأي
      // نقطة سابقة، هذا القرار يبقى ساري بغض النظر عن أي كاش محلي
      // "valid" قديم.
      final blockStatus = await _readActivationBlockStatus();
      if (blockStatus != null) {
        final blocked = _blockedActivationInfo(blockStatus);
        if (blocked != null) {
          return blocked;
        }
      }

      savedState = await _readSavedLicenseState();
      savedState = await _repairServerTokenCache(savedState);
      final savedToken = _licenseTokenFromCache(savedState);
      if (savedToken == null) {
        return _activationInfoFromLocalEvaluation();
      }

      // Startup and passive checks should be quick: evaluate the local license
      // state and only contact the server when the caller explicitly asks.
      if (!forceServerValidation) {
        return _activationInfoFromLocalEvaluation();
      }

      // Cache is stale or empty, proceed with network validation
      final savedDeviceId =
          savedState?['deviceId']?.toString() ?? await getDeviceId();
      final savedDeviceFingerprint =
          savedState?['deviceFingerprint']?.toString() ??
          await getDeviceFingerprint();

      if (savedDeviceId == null ||
          savedDeviceId.isEmpty ||
          savedDeviceFingerprint == null ||
          savedDeviceFingerprint.isEmpty) {
        await clearActivation();
        return {
          'has_activation': false,
          'status': 'not_activated',
          'signature_details': 'device_fingerprint_unavailable',
        };
      }

      final inactiveRequestState = await _rejectIfSavedRequestIsInactive(
        savedState: savedState,
        deviceId: savedDeviceId,
      );
      if (inactiveRequestState != null) {
        return inactiveRequestState;
      }

      final inactiveServerState = await _rejectIfServerDeviceIsInactive(
        deviceId: savedDeviceId,
        deviceFingerprint: savedDeviceFingerprint,
      );
      if (inactiveServerState != null) {
        return inactiveServerState;
      }

      final validation = await _apiClient.validateLicense(
        licenseToken: savedToken,
        deviceId: savedDeviceId,
        deviceFingerprint: savedDeviceFingerprint,
        clientTime: DateTime.now().toUtc().toIso8601String(),
      );
      final statusCode = validation['statusCode'] as int;
      final body = validation['body'] as Map<String, dynamic>;
      final responseData = _mapValue(body['data']);
      final isValid = responseData?['valid'] == true;

      if (statusCode != 200 || body['success'] != true || !isValid) {
        await clearActivation();
        return {
          'has_activation': false,
          'status': 'not_activated',
          'signature_details':
              responseData?['status']?.toString() ??
              body['message']?.toString() ??
              'license_validation_failed',
        };
      }

      final refreshedToken = responseData?['token']?.toString();
      final tokenHeader = _mapValue(responseData?['tokenHeader']);
      final claims = _mapValue(responseData?['claims']);
      final updatedState = Map<String, dynamic>.from(savedState ?? {});
      if (refreshedToken != null && refreshedToken.isNotEmpty) {
        updatedState['licenseToken'] = refreshedToken;
      }
      if (tokenHeader != null) {
        updatedState['tokenHeader'] = tokenHeader;
      }
      if (claims != null) {
        updatedState['claims'] = claims;
      }
      updatedState['deviceId'] = savedDeviceId;
      updatedState['deviceFingerprint'] = savedDeviceFingerprint;
      updatedState['lastValidationTime'] = DateTime.now().toIso8601String();
      updatedState['licenseStatus'] = 'valid';
      await _storage.saveLicenseCache(updatedState);
      await _clearActivationBlockStatus();

      return {
        'has_activation': true,
        'status': 'valid',
        'activation_type': claims?['type']?.toString() ?? 'permanent',
        'license_id': claims?['licenseId']?.toString(),
        'signature_details': responseData?['status']?.toString(),
        'allow_login': true,
        'can_use_current_session': true,
      };
    } catch (error, stackTrace) {
      appLog(
        'Activation info read failed.',
        name: 'ActivationService',
        error: error,
        stackTrace: stackTrace,
      );

      final savedToken = _licenseTokenFromCache(savedState);
      final localLicenseBlob = savedState?['licenseBlob']?.toString().trim();

      if (savedToken == null) {
        return {
          'has_activation': false,
          'status': 'not_activated',
          'signature_details': 'no_saved_activation',
        };
      }

      if (localLicenseBlob == null || localLicenseBlob.isEmpty) {
        await clearActivation();
        return {
          'has_activation': false,
          'status': 'not_activated',
          'signature_details': 'stale_activation_without_local_license',
        };
      }

      // أي خطأ غير متوقع هنا (سواء انقطاع اتصال أو غيره) ما لازم يمنح
      // دخول تلقائي. نرجع لقواعد تقييم الكاش المحلي الواضحة (فترة
      // السماح دون اتصال، درجة الثقة...)، وإذا فشل التقييم نفسه
      // نرفض الدخول (fail-closed) بدل منحه.
      try {
        final result = await _evaluateLicenseState();
        final status = result['status']?.toString() ?? 'not_activated';
        final cache = result['cache'] as Map<String, dynamic>?;
        final evaluation = result['evaluation'] as LicenseEvaluationResult?;

        if (status == 'not_activated' || cache == null) {
          await clearActivation();
          return {'has_activation': false, 'status': 'not_activated'};
        }

        final expiresAt = cache['expiresAt']?.toString();
        final remainingDays =
            expiresAt == null || expiresAt.isEmpty
                ? null
                : _calculateRemainingDays(expiresAt);

        return {
          'has_activation': true,
          'status': evaluation?.publicStatus ?? status,
          'license_id': cache['licenseId'],
          'activation_type': cache['licenseType'] ?? 'permanent',
          'expires_at': expiresAt,
          'remaining_days': remainingDays,
          'offline_grace_until':
              evaluation?.offlineGraceUntil?.toIso8601String() ??
              cache['offlineGraceUntil'],
          'next_revalidation_at':
              evaluation?.nextRevalidationAt?.toIso8601String(),
          'signature_details':
              cache['failureReason']?.toString() ?? evaluation?.reason,
          'verification_status':
              evaluation?.verificationStatus.name ?? status,
          'security_trust': evaluation?.trustScore?.toPublicMap(),
          'can_use_current_session': evaluation?.canUseCurrentSession == true,
          'allow_login': evaluation?.allowLogin == true,
        };
      } catch (_) {
        // فشل حتى تقييم الكاش المحلي => رفض الدخول، لا منحه أبدًا.
        return {
          'has_activation': false,
          'status': 'not_activated',
          'signature_details': 'license_check_failed',
        };
      }
    }
  }
  
  Future<void> beginCriticalOperation() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_criticalOperationDepthKey) ?? 0;
    await prefs.setInt(_criticalOperationDepthKey, current + 1);
  }

  Future<void> endCriticalOperation() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_criticalOperationDepthKey) ?? 0;
    if (current <= 1) {
      await prefs.remove(_criticalOperationDepthKey);
      return;
    }
    await prefs.setInt(_criticalOperationDepthKey, current - 1);
  }

  Future<bool> isInCriticalOperation() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_criticalOperationDepthKey) ?? 0) > 0;
  }

  Future<void> markSessionStarted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionStartedAtKey,
      DateTime.now().toIso8601String(),
    );
  }

  Future<Map<String, dynamic>> attemptBackgroundRevalidation() async {
    if (await isInCriticalOperation()) {
      return {
        'success': false,
        'status': 'deferred',
        'message': 'تم تأجيل فحص الترخيص لأن هناك عملية حساسة جارية.',
      };
    }

    try {
      final savedState = await _readSavedLicenseState();
      final savedToken = _licenseTokenFromCache(savedState);
      if (savedToken == null) {
        return {
          'success': false,
          'status': 'not_activated',
          'message': 'لا يوجد licenseToken محفوظ.',
        };
      }

      final deviceId =
          savedState?['deviceId']?.toString() ?? await getDeviceId();
      final deviceFingerprint =
          savedState?['deviceFingerprint']?.toString() ??
          await getDeviceFingerprint();

      if (deviceId == null ||
          deviceId.isEmpty ||
          deviceFingerprint == null ||
          deviceFingerprint.isEmpty) {
        await clearActivation();
        return {
          'success': false,
          'status': 'not_activated',
          'message': 'تعذر قراءة بصمة الجهاز.',
        };
      }

      final validation = await _apiClient.validateLicense(
        licenseToken: savedToken,
        deviceId: deviceId,
        deviceFingerprint: deviceFingerprint,
        clientTime: DateTime.now().toUtc().toIso8601String(),
      );
      final body = validation['body'] as Map<String, dynamic>;
      final data = _mapValue(body['data']);

      if (body['success'] != true || data?['valid'] != true) {
        await clearActivation();
        return {
          'success': false,
          'status': data?['status']?.toString() ?? 'invalid',
          'message': _messageOrDefault(body['message'], 'License invalid'),
        };
      }

      final updated = Map<String, dynamic>.from(savedState ?? {});
      final refreshedToken = data?['token']?.toString();
      if (refreshedToken != null && refreshedToken.isNotEmpty) {
        updated['licenseToken'] = refreshedToken;
      }
      final tokenHeader = _mapValue(data?['tokenHeader']);
      final claims = _mapValue(data?['claims']);
      if (tokenHeader != null) updated['tokenHeader'] = tokenHeader;
      if (claims != null) updated['claims'] = claims;
      updated['deviceId'] = deviceId;
      updated['deviceFingerprint'] = deviceFingerprint;
      updated['lastValidationTime'] = DateTime.now().toIso8601String();
      updated['licenseStatus'] = 'valid';
      await _storage.saveLicenseCache(updated);

      return {
        'success': true,
        'status': data?['status']?.toString() ?? 'valid',
        'message': _messageOrDefault(
          body['message'],
          'License revalidated successfully',
        ),
      };
    } catch (error, stackTrace) {
      appLog(
        'License revalidation failed.',
        name: 'ActivationService',
        error: error,
        stackTrace: stackTrace,
      );
      return {
        'success': false,
        'status': 'validation_failed',
        'message': 'تعذر إعادة التحقق من الترخيص.',
      };
    }

    final info = await getActivationInfo();
    if (await isInCriticalOperation()) {
      return {
        'success': false,
        'status': 'deferred',
        'message': 'تم تأجيل الفحص لأن هناك عملية حساسة جارية.',
      };
    }

    if (info['status'] == 'valid' || info['status'] == 'grace_period') {
      // TODO(server): call server-side token refresh here when the API exists.
      return {
        'success': true,
        'status': 'skipped',
        'message': 'لا يوجد endpoint لإعادة التحقق حتى الآن.',
      };
    }

    return {
      'success': false,
      'status': info['status'],
      'message': 'يتطلب الترخيص إعادة تحقق عبر الإنترنت.',
    };
  }

  Future<Map<String, dynamic>?> getSavedPendingRequest() {
    return _storage.getSavedPendingRequest();
  }

  Future<void> clearPendingRequest() {
    return _storage.clearPendingRequest();
  }

  Future<void> clearPendingRequestCode() {
    return _storage.clearPendingRequestCode();
  }

  Future<void> checkDatabase() async {
    // Legacy no-op retained for backward compatibility.
  }
}
