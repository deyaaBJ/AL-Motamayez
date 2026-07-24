import 'dart:convert';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:motamayez/services/security/security_native_bridge.dart';

final class LicenseValidationResult {
  const LicenseValidationResult({
    required this.isValid,
    required this.status,
    this.reason,
    this.license,
  });

  final bool isValid;
  final String status;
  final String? reason;
  final Map<String, dynamic>? license;
}

final class LicenseValidator {
  LicenseValidator({
    required String publicKeyPem,
    required String Function(String) normalizeActivationCode,
  }) : _publicKeyPem = publicKeyPem,
       _normalizeActivationCode = normalizeActivationCode;

  final String _publicKeyPem;
  final String Function(String) _normalizeActivationCode;

  LicenseValidationResult validateSignedLicense({
    required Map<String, dynamic> licenseEnvelope,
    required String expectedDeviceHash,
    required DateTime now,
  }) {
    final license = _extractLicenseData(licenseEnvelope);
    final signature = licenseEnvelope['signature']?.toString();

    if (license == null || signature == null || signature.isEmpty) {
      return const LicenseValidationResult(
        isValid: false,
        status: 'invalid',
        reason: 'missing_signed_license_blob',
      );
    }

    final payload = _buildSignaturePayload(license);
    if (payload == null) {
      return const LicenseValidationResult(
        isValid: false,
        status: 'invalid',
        reason: 'invalid_signed_payload',
      );
    }

    final nativePayloadHash = SecurityNativeBridge.instance.hash64(
      Uint8List.fromList(utf8.encode(payload)),
    );
    if (nativePayloadHash == null || nativePayloadHash == 0) {
      return const LicenseValidationResult(
        isValid: false,
        status: 'invalid',
        reason: 'native_verification_unavailable',
      );
    }

    final boundDevice = license['deviceId']?.toString().trim();
    if (boundDevice == null || boundDevice != expectedDeviceHash) {
      return const LicenseValidationResult(
        isValid: false,
        status: 'invalid',
        reason: 'device_binding_mismatch',
      );
    }

    try {
      final publicKey = CryptoUtils.rsaPublicKeyFromPem(_publicKeyPem);
      final signatureBytes = base64Decode(signature);
      final verified = CryptoUtils.rsaVerify(
        publicKey,
        Uint8List.fromList(utf8.encode(payload)),
        signatureBytes,
      );

      if (!verified) {
        return const LicenseValidationResult(
          isValid: false,
          status: 'invalid',
          reason: 'signature_verification_failed',
        );
      }
    } on FormatException {
      return const LicenseValidationResult(
        isValid: false,
        status: 'invalid',
        reason: 'signature_format_invalid',
      );
    } catch (_) {
      return const LicenseValidationResult(
        isValid: false,
        status: 'invalid',
        reason: 'signature_validation_error',
      );
    }

    final type = classifyLicenseType(license);
    if (type == 'temporary') {
      final expiresAt = DateTime.tryParse(license['expiresAt']?.toString() ?? '');
      if (expiresAt == null) {
        return const LicenseValidationResult(
          isValid: false,
          status: 'invalid',
          reason: 'temporary_license_missing_expiry',
        );
      }

      if (!expiresAt.isAfter(now)) {
        return const LicenseValidationResult(
          isValid: false,
          status: 'expired',
          reason: 'temporary_license_expired',
        );
      }
    }

    return LicenseValidationResult(
      isValid: true,
      status: 'valid',
      license: license,
    );
  }

  Map<String, dynamic>? _extractLicenseData(Map<String, dynamic> envelope) {
    final activation = envelope['license'] ?? envelope['activation'];
    if (activation is Map<String, dynamic>) {
      return activation;
    }
    return null;
  }

  String? _buildSignaturePayload(Map<String, dynamic> activationData) {
    final deviceId = activationData['deviceId']?.toString().trim();
    final activationCodeValue =
        activationData['activationCode']?.toString() ??
        activationData['code']?.toString();
    final activationCode =
        activationCodeValue == null
            ? null
            : _normalizeActivationCode(activationCodeValue);

    if (deviceId == null || deviceId.isEmpty) return null;
    if (activationCode == null || activationCode.isEmpty) return null;

    if (classifyLicenseType(activationData) == 'temporary') {
      final expiresAt = activationData['expiresAt']?.toString().trim();
      if (expiresAt == null || expiresAt.isEmpty) return null;
      return '$deviceId|$activationCode|$expiresAt';
    }

    return '$deviceId|$activationCode|LIFETIME';
  }

  String classifyLicenseType(Map<String, dynamic> activationData) {
    final code =
        activationData['activationCode']?.toString() ??
        activationData['code']?.toString() ??
        '';
    return RegExp(r'^DAY-?(\d+)$', caseSensitive: false).hasMatch(code.trim())
        ? 'temporary'
        : 'permanent';
  }
}
