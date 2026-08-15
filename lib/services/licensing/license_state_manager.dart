import 'dart:convert';

import 'package:motamayez/services/licensing/license_storage.dart';
import 'package:motamayez/services/licensing/license_validator.dart';
import 'package:motamayez/services/security/security_runtime_service.dart';
import 'package:motamayez/services/security/security_trust_score.dart';

enum LicenseVerificationStatus {
  valid,
  expired,
  invalidSignature,
  deviceMismatch,
  needsRevalidation,
  notActivated,
}

final class LicenseEvaluationResult {
  const LicenseEvaluationResult({
    required this.verificationStatus,
    required this.publicStatus,
    required this.allowLogin,
    required this.canUseCurrentSession,
    this.reason,
    this.cache,
    this.license,
    this.trustScore,
    this.nextRevalidationAt,
    this.offlineGraceUntil,
  });

  final LicenseVerificationStatus verificationStatus;
  final String publicStatus;
  final bool allowLogin;
  final bool canUseCurrentSession;
  final String? reason;
  final Map<String, dynamic>? cache;
  final Map<String, dynamic>? license;
  final SecurityTrustScore? trustScore;
  final DateTime? nextRevalidationAt;
  final DateTime? offlineGraceUntil;

  bool get isValid => verificationStatus == LicenseVerificationStatus.valid;
}

typedef DeviceFingerprintResolver = Future<String?> Function();

final class LicenseStateManager {
  LicenseStateManager({
    required LicenseStorage storage,
    required LicenseValidator validator,
    required DeviceFingerprintResolver resolveDeviceFingerprint,
    SecurityRuntimeService? securityRuntime,
  }) : _storage = storage,
       _validator = validator,
       _resolveDeviceFingerprint = resolveDeviceFingerprint,
       _securityRuntime = securityRuntime ?? SecurityRuntimeService.instance;

  final LicenseStorage _storage;
  final LicenseValidator _validator;
  final DeviceFingerprintResolver _resolveDeviceFingerprint;
  final SecurityRuntimeService _securityRuntime;

  static const Duration permanentRevalidationInterval = Duration(days: 5);
  static const Duration permanentOfflineGrace = Duration.zero;
  static const Duration temporaryRevalidationInterval = Duration(hours: 24);
  static const Duration temporaryOfflineGrace = Duration(hours: 12);
  static const Duration suspiciousClockRollback = Duration(hours: 6);

  Future<Map<String, dynamic>?> loadLicenseCache() async {
    final cache = await _storage.readLicenseCache();
    if (cache == null) return null;

    final expectedIntegrity = cache['integrity']?.toString();
    if (expectedIntegrity == null ||
        expectedIntegrity != LicenseStorage.computeIntegrityHash(cache)) {
      final updated =
          Map<String, dynamic>.from(cache)
            ..['licenseStatus'] = 'needs_revalidation'
            ..['failureReason'] = 'cache_integrity_check_failed'
            ..['tamperDetected'] = true;
      await persistLicenseCache(updated);
      return updated;
    }

    return cache;
  }

  Future<void> persistLicenseCache(Map<String, dynamic> cache) async {
    final updated = Map<String, dynamic>.from(cache);
    updated['integrity'] = LicenseStorage.computeIntegrityHash(updated);
    await _storage.saveLicenseCache(updated);
  }

  DateTime computeOfflineGraceUntil({
    required DateTime now,
    required String licenseType,
  }) {
    return now.add(
      licenseType == 'temporary'
          ? temporaryOfflineGrace
          : permanentOfflineGrace,
    );
  }

  Future<LicenseEvaluationResult> evaluate({
    DateTime? now,
    Map<String, dynamic>? cacheOverride,
  }) async {
    final currentTime = now ?? DateTime.now();
    final trustScore = await _securityRuntime.start();
    final cache = cacheOverride ?? await loadLicenseCache();
    if (cache == null) {
      return LicenseEvaluationResult(
        verificationStatus: LicenseVerificationStatus.notActivated,
        publicStatus: 'not_activated',
        allowLogin: false,
        canUseCurrentSession: false,
        trustScore: trustScore,
      );
    }

    final deviceFingerprint = await _resolveDeviceFingerprint();
    if (deviceFingerprint == null || deviceFingerprint.isEmpty) {
      final updated =
          Map<String, dynamic>.from(cache)
            ..['licenseStatus'] = 'needs_revalidation'
            ..['failureReason'] = 'device_fingerprint_unavailable'
            ..['tamperDetected'] = true;
      await persistLicenseCache(updated);
      return LicenseEvaluationResult(
        verificationStatus: LicenseVerificationStatus.needsRevalidation,
        publicStatus: 'needs_revalidation',
        allowLogin: false,
        canUseCurrentSession: true,
        reason: 'device_fingerprint_unavailable',
        cache: updated,
        trustScore: trustScore,
      );
    }

    final cachedDeviceHash = cache['deviceHash']?.toString();
    if (cachedDeviceHash == null ||
        cachedDeviceHash.isEmpty ||
        cachedDeviceHash != deviceFingerprint) {
      final updated =
          Map<String, dynamic>.from(cache)
            ..['licenseStatus'] = 'invalid'
            ..['failureReason'] = 'device_binding_changed'
            ..['tamperDetected'] = true;
      await persistLicenseCache(updated);
      return LicenseEvaluationResult(
        verificationStatus: LicenseVerificationStatus.deviceMismatch,
        publicStatus: 'invalid',
        allowLogin: false,
        canUseCurrentSession: false,
        reason: 'device_binding_changed',
        cache: updated,
        trustScore: trustScore,
      );
    }

    final licenseBlobRaw = cache['licenseBlob']?.toString();
    if (licenseBlobRaw == null || licenseBlobRaw.isEmpty) {
      final updated =
          Map<String, dynamic>.from(cache)
            ..['licenseStatus'] = 'needs_revalidation'
            ..['failureReason'] = 'missing_signed_license_blob'
            ..['tamperDetected'] = true;
      await persistLicenseCache(updated);
      return LicenseEvaluationResult(
        verificationStatus: LicenseVerificationStatus.needsRevalidation,
        publicStatus: 'needs_revalidation',
        allowLogin: false,
        canUseCurrentSession: true,
        reason: 'missing_signed_license_blob',
        cache: updated,
        trustScore: trustScore,
      );
    }

    try {
      final envelope = jsonDecode(licenseBlobRaw);
      if (envelope is! Map<String, dynamic>) {
        throw const FormatException('invalid_blob');
      }

      if (_isServerTokenLicense(cache: cache, envelope: envelope)) {
        return _evaluateServerTokenLicense(
          cache: cache,
          envelope: envelope,
          now: currentTime,
          trustScore: trustScore,
        );
      }

      final validation = _validator.validateSignedLicense(
        licenseEnvelope: envelope,
        expectedDeviceHash: deviceFingerprint,
        now: currentTime,
      );

      if (!validation.isValid) {
        return _handleValidationFailure(
          cache: cache,
          validation: validation,
          trustScore: trustScore,
        );
      }

      final updated =
          Map<String, dynamic>.from(cache)
            ..['licenseStatus'] = 'valid'
            ..['failureReason'] = null
            ..['tamperDetected'] = trustScore.suspiciousRuntime
            ..['runtimeTrustScore'] = trustScore.score
            ..['runtimeSignals'] =
                trustScore.signals.map((signal) => signal.name).toList()
            ..['deviceHash'] = deviceFingerprint
            ..['licenseType'] = _validator.classifyLicenseType(
              validation.license!,
            )
            ..['licenseId'] =
                validation.license!['licenseId']?.toString() ??
                cache['licenseId']?.toString()
            ..['expiresAt'] = validation.license!['expiresAt']?.toString()
            ..['activatedAt'] =
                validation.license!['activatedAt']?.toString() ??
                cache['activatedAt']?.toString();

      if (await _storage.hasLegacySensitiveState()) {
        updated['licenseStatus'] = 'needs_revalidation';
        updated['failureReason'] = 'legacy_sensitive_state_detected';
        await _storage.clearLegacySensitiveState();
        await persistLicenseCache(updated);
        return LicenseEvaluationResult(
          verificationStatus: LicenseVerificationStatus.needsRevalidation,
          publicStatus: 'needs_revalidation',
          allowLogin: false,
          canUseCurrentSession: true,
          reason: 'legacy_sensitive_state_detected',
          cache: updated,
          license: validation.license,
          trustScore: trustScore,
        );
      }

      await persistLicenseCache(updated);
      return _applyRevalidationPolicy(
        cache: updated,
        license: validation.license!,
        now: currentTime,
        trustScore: trustScore,
      );
    } catch (_) {
      final updated =
          Map<String, dynamic>.from(cache)
            ..['licenseStatus'] = 'needs_revalidation'
            ..['failureReason'] = 'license_blob_corrupted'
            ..['tamperDetected'] = true;
      await persistLicenseCache(updated);
      return LicenseEvaluationResult(
        verificationStatus: LicenseVerificationStatus.needsRevalidation,
        publicStatus: 'needs_revalidation',
        allowLogin: false,
        canUseCurrentSession: true,
        reason: 'license_blob_corrupted',
        cache: updated,
        trustScore: trustScore,
      );
    }
  }

  bool _isServerTokenLicense({
    required Map<String, dynamic> cache,
    required Map<String, dynamic> envelope,
  }) {
    final token =
        envelope['token']?.toString() ?? cache['licenseToken']?.toString();
    final signature = envelope['signature']?.toString();
    return cache['licenseSource'] == 'server_token' ||
        (token != null &&
            token.isNotEmpty &&
            (signature == null || signature.isEmpty));
  }

  Future<LicenseEvaluationResult> _evaluateServerTokenLicense({
    required Map<String, dynamic> cache,
    required Map<String, dynamic> envelope,
    required DateTime now,
    required SecurityTrustScore trustScore,
  }) async {
    final license = _extractLicenseData(envelope);
    if (license == null || license.isEmpty) {
      final updated =
          Map<String, dynamic>.from(cache)
            ..['licenseStatus'] = 'needs_revalidation'
            ..['failureReason'] = 'missing_license_data';
      await persistLicenseCache(updated);
      return LicenseEvaluationResult(
        verificationStatus: LicenseVerificationStatus.needsRevalidation,
        publicStatus: 'needs_revalidation',
        allowLogin: false,
        canUseCurrentSession: true,
        reason: 'missing_license_data',
        cache: updated,
        trustScore: trustScore,
      );
    }

    final serverStatus =
        license['status']?.toString() ?? cache['serverStatus']?.toString();
    final normalizedServerStatus = serverStatus?.toLowerCase();
    if (normalizedServerStatus != null &&
        normalizedServerStatus.isNotEmpty &&
        normalizedServerStatus != 'active' &&
        normalizedServerStatus != 'valid') {
      final updated =
          Map<String, dynamic>.from(cache)
            ..['licenseStatus'] = 'needs_revalidation'
            ..['failureReason'] = 'server_license_not_active'
            ..['serverStatus'] = serverStatus;
      await persistLicenseCache(updated);
      return LicenseEvaluationResult(
        verificationStatus: LicenseVerificationStatus.needsRevalidation,
        publicStatus: 'needs_revalidation',
        allowLogin: false,
        canUseCurrentSession: true,
        reason: 'server_license_not_active',
        cache: updated,
        license: license,
        trustScore: trustScore,
      );
    }

    final expiresAtRaw =
        license['expiresAt']?.toString() ?? cache['expiresAt']?.toString();
    final expiresAt =
        expiresAtRaw == null || expiresAtRaw.isEmpty
            ? null
            : DateTime.tryParse(expiresAtRaw);
    if (expiresAt != null && !expiresAt.isAfter(now)) {
      final updated =
          Map<String, dynamic>.from(cache)
            ..['licenseStatus'] = 'needs_revalidation'
            ..['failureReason'] = 'license_expired'
            ..['expiresAt'] = expiresAtRaw;
      await persistLicenseCache(updated);
      return LicenseEvaluationResult(
        verificationStatus: LicenseVerificationStatus.expired,
        publicStatus: 'needs_revalidation',
        allowLogin: false,
        canUseCurrentSession: true,
        reason: 'license_expired',
        cache: updated,
        license: license,
        trustScore: trustScore,
      );
    }

    final licenseType =
        license['type']?.toString() ??
        cache['licenseType']?.toString() ??
        'permanent';
    final updated =
        Map<String, dynamic>.from(cache)
          ..['licenseStatus'] = 'valid'
          ..['failureReason'] = null
          ..['licenseSource'] = 'server_token'
          ..['licenseType'] = licenseType
          ..['licenseId'] =
              license['licenseId']?.toString() ??
              license['id']?.toString() ??
              cache['licenseId']?.toString()
          ..['expiresAt'] = expiresAtRaw
          ..['serverStatus'] = serverStatus
          ..['tamperDetected'] = trustScore.suspiciousRuntime
          ..['runtimeTrustScore'] = trustScore.score
          ..['runtimeSignals'] =
              trustScore.signals.map((signal) => signal.name).toList();

    if (await _storage.hasLegacySensitiveState()) {
      updated['licenseStatus'] = 'needs_revalidation';
      updated['failureReason'] = 'legacy_sensitive_state_detected';
      await _storage.clearLegacySensitiveState();
      await persistLicenseCache(updated);
      return LicenseEvaluationResult(
        verificationStatus: LicenseVerificationStatus.needsRevalidation,
        publicStatus: 'needs_revalidation',
        allowLogin: false,
        canUseCurrentSession: true,
        reason: 'legacy_sensitive_state_detected',
        cache: updated,
        license: license,
        trustScore: trustScore,
      );
    }

    await persistLicenseCache(updated);
    return _applyRevalidationPolicy(
      cache: updated,
      license: license,
      now: now,
      trustScore: trustScore,
    );
  }

  Map<String, dynamic>? _extractLicenseData(Map<String, dynamic> envelope) {
    final license = envelope['license'] ?? envelope['activation'];
    return license is Map<String, dynamic> ? license : null;
  }

  Future<LicenseEvaluationResult> validateLicenseEnvelope({
    required Map<String, dynamic> licenseEnvelope,
    required DateTime now,
  }) async {
    final trustScore = await _securityRuntime.scanNow();
    final deviceFingerprint = await _resolveDeviceFingerprint();
    if (deviceFingerprint == null || deviceFingerprint.isEmpty) {
      return LicenseEvaluationResult(
        verificationStatus: LicenseVerificationStatus.needsRevalidation,
        publicStatus: 'needs_revalidation',
        allowLogin: false,
        canUseCurrentSession: true,
        reason: 'device_fingerprint_unavailable',
        trustScore: trustScore,
      );
    }

    final validation = _validator.validateSignedLicense(
      licenseEnvelope: licenseEnvelope,
      expectedDeviceHash: deviceFingerprint,
      now: now,
    );

    if (!validation.isValid) {
      return _mapValidationFailure(validation, trustScore: trustScore);
    }

    if (trustScore.blocksNewLogin) {
      return LicenseEvaluationResult(
        verificationStatus: LicenseVerificationStatus.needsRevalidation,
        publicStatus: 'runtime_suspicious',
        allowLogin: false,
        canUseCurrentSession: false,
        reason: 'runtime_trust_below_login_threshold',
        license: validation.license,
        trustScore: trustScore,
      );
    }

    return LicenseEvaluationResult(
      verificationStatus: LicenseVerificationStatus.valid,
      publicStatus: 'valid',
      allowLogin: true,
      canUseCurrentSession: true,
      license: validation.license,
      trustScore: trustScore,
    );
  }

  Future<LicenseEvaluationResult> _handleValidationFailure({
    required Map<String, dynamic> cache,
    required LicenseValidationResult validation,
    required SecurityTrustScore trustScore,
  }) async {
    final mapped = _mapValidationFailure(validation, trustScore: trustScore);
    final updated =
        Map<String, dynamic>.from(cache)
          ..['licenseStatus'] = mapped.publicStatus
          ..['failureReason'] = mapped.reason;

    if (mapped.verificationStatus == LicenseVerificationStatus.expired) {
      updated['licenseStatus'] = 'needs_revalidation';
    }

    await persistLicenseCache(updated);
    return LicenseEvaluationResult(
      verificationStatus: mapped.verificationStatus,
      publicStatus:
          mapped.verificationStatus == LicenseVerificationStatus.expired
              ? 'needs_revalidation'
              : mapped.publicStatus,
      allowLogin: false,
      canUseCurrentSession:
          mapped.verificationStatus == LicenseVerificationStatus.expired,
      reason: mapped.reason,
      cache: updated,
      trustScore: trustScore,
    );
  }

  LicenseEvaluationResult _mapValidationFailure(
    LicenseValidationResult validation, {
    SecurityTrustScore? trustScore,
  }) {
    switch (validation.reason) {
      case 'device_binding_mismatch':
        return LicenseEvaluationResult(
          verificationStatus: LicenseVerificationStatus.deviceMismatch,
          publicStatus: 'invalid',
          allowLogin: false,
          canUseCurrentSession: false,
          reason: 'device_binding_mismatch',
          trustScore: trustScore,
        );
      case 'temporary_license_expired':
        return LicenseEvaluationResult(
          verificationStatus: LicenseVerificationStatus.expired,
          publicStatus: 'expired',
          allowLogin: false,
          canUseCurrentSession: true,
          reason: 'temporary_license_expired',
          trustScore: trustScore,
        );
      case 'signature_verification_failed':
      case 'signature_format_invalid':
      case 'signature_validation_error':
        return LicenseEvaluationResult(
          verificationStatus: LicenseVerificationStatus.invalidSignature,
          publicStatus: 'invalid',
          allowLogin: false,
          canUseCurrentSession: false,
          reason: validation.reason,
          trustScore: trustScore,
        );
      default:
        return LicenseEvaluationResult(
          verificationStatus: LicenseVerificationStatus.needsRevalidation,
          publicStatus: 'needs_revalidation',
          allowLogin: false,
          canUseCurrentSession: true,
          reason: validation.reason ?? 'license_validation_failed',
          trustScore: trustScore,
        );
    }
  }

  LicenseEvaluationResult _applyRevalidationPolicy({
    required Map<String, dynamic> cache,
    required Map<String, dynamic> license,
    required DateTime now,
    required SecurityTrustScore trustScore,
  }) {
    final lastValidatedAt = DateTime.tryParse(
      cache['lastValidationAt']?.toString() ?? '',
    );
    final lastKnownServerTime = DateTime.tryParse(
      cache['lastKnownServerTime']?.toString() ?? '',
    );
    final offlineGraceUntil = DateTime.tryParse(
      cache['offlineGraceUntil']?.toString() ?? '',
    );
    final licenseType = cache['licenseType']?.toString() ?? 'permanent';

    if (lastKnownServerTime != null &&
        now.isBefore(lastKnownServerTime.subtract(suspiciousClockRollback))) {
      return LicenseEvaluationResult(
        verificationStatus: LicenseVerificationStatus.needsRevalidation,
        publicStatus: 'clock_tampering_detected',
        allowLogin: false,
        canUseCurrentSession: true,
        reason: 'device_clock_rollback_detected',
        cache: cache,
        license: license,
        trustScore: trustScore,
      );
    }

    if (trustScore.blocksNewLogin) {
      return LicenseEvaluationResult(
        verificationStatus: LicenseVerificationStatus.needsRevalidation,
        publicStatus: 'runtime_suspicious',
        allowLogin: false,
        canUseCurrentSession: false,
        reason: 'runtime_trust_below_login_threshold',
        cache: cache,
        license: license,
        trustScore: trustScore,
      );
    }

    if (trustScore.requiresRevalidation) {
      return LicenseEvaluationResult(
        verificationStatus: LicenseVerificationStatus.needsRevalidation,
        publicStatus: 'needs_revalidation',
        allowLogin: false,
        canUseCurrentSession: true,
        reason: 'runtime_trust_requires_revalidation',
        cache: cache,
        license: license,
        trustScore: trustScore,
      );
    }

    if (lastValidatedAt == null) {
      return LicenseEvaluationResult(
        verificationStatus: LicenseVerificationStatus.needsRevalidation,
        publicStatus: 'needs_revalidation',
        allowLogin: false,
        canUseCurrentSession: true,
        reason: 'missing_last_validation',
        cache: cache,
        license: license,
        trustScore: trustScore,
      );
    }

    final interval =
        licenseType == 'temporary'
            ? temporaryRevalidationInterval
            : permanentRevalidationInterval;
    final nextRevalidationAt = lastValidatedAt.add(interval);

    if (now.isBefore(nextRevalidationAt)) {
      return LicenseEvaluationResult(
        verificationStatus: LicenseVerificationStatus.valid,
        publicStatus: 'valid',
        allowLogin: true,
        canUseCurrentSession: true,
        cache: cache,
        license: license,
        nextRevalidationAt: nextRevalidationAt,
        trustScore: trustScore,
      );
    }

    final computedGraceUntil = lastValidatedAt.add(
      trustScore.constrainOfflineGrace(
        licenseType == 'temporary'
            ? temporaryOfflineGrace
            : permanentOfflineGrace,
      ),
    );
    final constrainedGraceUntil =
        offlineGraceUntil != null &&
                offlineGraceUntil.isBefore(computedGraceUntil)
            ? offlineGraceUntil
            : computedGraceUntil;

    if (now.isBefore(constrainedGraceUntil)) {
      // ما زال ضمن فترة السماح الإضافية (إن وُجدت) دون اتصال.
      return LicenseEvaluationResult(
        verificationStatus: LicenseVerificationStatus.valid,
        publicStatus: 'grace_period',
        allowLogin: true,
        canUseCurrentSession: true,
        reason: 'revalidation_due_in_grace_period',
        cache: cache,
        license: license,
        nextRevalidationAt: nextRevalidationAt,
        offlineGraceUntil: constrainedGraceUntil,
        trustScore: trustScore,
      );
    }

    // انقضت 5 أيام بالضبط (permanentRevalidationInterval) من آخر تحقق
    // ناجح مع السيرفر، دون أي إعادة تحقق نجحت خلالها. هذا هو الحد
    // القاطع: يُمنع الدخول لحد ما يتصل بالنت ويتحقق من جديد، بغض
    // النظر عن صحة التوقيع المحلي أو عدم وجود expiresAt.
    return LicenseEvaluationResult(
      verificationStatus: LicenseVerificationStatus.needsRevalidation,
      publicStatus: 'needs_revalidation',
      allowLogin: false,
      canUseCurrentSession: false,
      reason: 'offline_grace_period_expired',
      cache: cache,
      license: license,
      nextRevalidationAt: nextRevalidationAt,
      offlineGraceUntil: constrainedGraceUntil,
      trustScore: trustScore,
    );
  }
}
