import 'dart:async';

import 'package:flutter/material.dart';
import 'package:motamayez/providers/auth_provider.dart';
import 'package:motamayez/screens/activation_page.dart';
import 'package:motamayez/screens/activation_validation_required_screen.dart';
import 'package:motamayez/services/activation_service.dart';
import 'package:motamayez/utils/app_logger.dart';

class LicenseSessionGuard {
  LicenseSessionGuard._();

  static final LicenseSessionGuard instance = LicenseSessionGuard._();
  static const Duration _warningLeadTime = Duration(minutes: 5);

  final ActivationService _activationService = ActivationService();
  final ValueNotifier<LicenseSessionWarning?> warning = ValueNotifier(null);
  Timer? _timer;
  Timer? _warningTimer;
  bool _checking = false;

  void start({
    required AuthProvider authProvider,
    required NavigatorState navigator,
  }) {
    stop();
    unawaited(_scheduleNext(authProvider: authProvider, navigator: navigator));
  }

  void stop() {
    _timer?.cancel();
    _warningTimer?.cancel();
    _timer = null;
    _warningTimer = null;
    warning.value = null;
    _checking = false;
  }

  Future<void> _scheduleNext({
    required AuthProvider authProvider,
    required NavigatorState navigator,
  }) async {
    if (!authProvider.isLoggedIn) return;

    final info = await _activationService.getActivationInfo(
      forceServerValidation: false,
    );
    if (!authProvider.isLoggedIn) return;

    final status = info['status']?.toString();
    if (status != 'valid' && status != 'grace_period') {
      await _endSession(
        authProvider: authProvider,
        navigator: navigator,
        info: info,
      );
      return;
    }

    final deadline = _nextImportantDeadline(info);
    if (deadline == null) return;

    final now = DateTime.now();
    final nextCheckAt = deadline.time;
    final delay =
        nextCheckAt.isAfter(now)
            ? nextCheckAt.difference(now)
            : const Duration(seconds: 1);

    _scheduleWarning(deadline: deadline, now: now);

    _timer = Timer(delay, () {
      unawaited(
        _handleDueTime(authProvider: authProvider, navigator: navigator),
      );
    });
  }

  _LicenseSessionDeadline? _nextImportantDeadline(Map<String, dynamic> info) {
    final candidates = <_LicenseSessionDeadline>[];
    final status = info['status']?.toString();

    final expiresAt = _parseDate(info['expires_at']);
    if (expiresAt != null) {
      candidates.add(
        _LicenseSessionDeadline(
          time: expiresAt,
          type: _LicenseSessionDeadlineType.expiration,
        ),
      );
    }

    if (status == 'grace_period') {
      final offlineGraceUntil = _parseDate(info['offline_grace_until']);
      if (offlineGraceUntil != null) {
        candidates.add(
          _LicenseSessionDeadline(
            time: offlineGraceUntil,
            type: _LicenseSessionDeadlineType.offlineGrace,
          ),
        );
      }
    } else {
      final nextRevalidationAt = _parseDate(info['next_revalidation_at']);
      if (nextRevalidationAt != null) {
        candidates.add(
          _LicenseSessionDeadline(
            time: nextRevalidationAt,
            type: _LicenseSessionDeadlineType.revalidation,
          ),
        );
      }
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.time.compareTo(b.time));
    return candidates.first;
  }

  void _scheduleWarning({
    required _LicenseSessionDeadline deadline,
    required DateTime now,
  }) {
    _warningTimer?.cancel();
    _warningTimer = null;
    warning.value = null;

    final warningAt = deadline.time.subtract(_warningLeadTime);
    if (!warningAt.isAfter(now)) {
      _showWarning(deadline);
      return;
    }

    _warningTimer = Timer(warningAt.difference(now), () {
      _showWarning(deadline);
    });
  }

  void _showWarning(_LicenseSessionDeadline deadline) {
    warning.value = LicenseSessionWarning(
      title: deadline.warningTitle,
      message: deadline.warningMessage,
      deadline: deadline.time,
    );
  }

  DateTime? _parseDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _handleDueTime({
    required AuthProvider authProvider,
    required NavigatorState navigator,
  }) async {
    if (_checking || !authProvider.isLoggedIn) return;

    _checking = true;
    _warningTimer?.cancel();
    _warningTimer = null;
    warning.value = null;
    try {
      final localInfo = await _activationService.getActivationInfo(
        forceServerValidation: false,
      );
      if (!authProvider.isLoggedIn) return;

      final expiresAt = _parseDate(localInfo['expires_at']);
      if (expiresAt != null && !DateTime.now().isBefore(expiresAt)) {
        await _endSession(
          authProvider: authProvider,
          navigator: navigator,
          info: {
            ...localInfo,
            'status': 'expired',
            'signature_details': 'license_expired',
          },
        );
        return;
      }

      final nextRevalidationAt = _parseDate(localInfo['next_revalidation_at']);
      final revalidationDue =
          nextRevalidationAt != null &&
          !DateTime.now().isBefore(nextRevalidationAt);

      final info =
          revalidationDue
              ? await _activationService.getActivationInfo(
                forceServerValidation: true,
              )
              : localInfo;

      if (!authProvider.isLoggedIn) return;

      final status = info['status']?.toString();
      if (status == 'valid' || status == 'grace_period') {
        _checking = false;
        await _scheduleNext(authProvider: authProvider, navigator: navigator);
        return;
      }

      await _endSession(
        authProvider: authProvider,
        navigator: navigator,
        info: info,
      );
    } catch (error, stackTrace) {
      appLog(
        'License session guard failed.',
        name: 'LicenseSessionGuard',
        error: error,
        stackTrace: stackTrace,
      );
      _checking = false;
      await _scheduleNext(authProvider: authProvider, navigator: navigator);
    }
  }

  Future<void> _endSession({
    required AuthProvider authProvider,
    required NavigatorState navigator,
    required Map<String, dynamic> info,
  }) async {
    stop();
    if (!authProvider.isLoggedIn) return;

    await authProvider.logout();
    if (!navigator.mounted) return;

    final status = info['status']?.toString();
    final reason = info['signature_details']?.toString();
    final expired =
        status == 'expired' ||
        reason == 'license_expired' ||
        reason == 'temporary_license_expired';

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder:
            (_) =>
                expired
                    ? const ActivationPage(
                      initialMessage:
                          'انتهت مدة الاشتراك. يرجى إرسال طلب تجديد ثم إدخال كود التفعيل الجديد بعد الموافقة.',
                      renewalMode: true,
                    )
                    : ActivationValidationRequiredScreen(message: reason),
      ),
      (route) => false,
    );
  }
}

class LicenseSessionWarning {
  const LicenseSessionWarning({
    required this.title,
    required this.message,
    required this.deadline,
  });

  final String title;
  final String message;
  final DateTime deadline;
}

enum _LicenseSessionDeadlineType { expiration, revalidation, offlineGrace }

class _LicenseSessionDeadline {
  const _LicenseSessionDeadline({required this.time, required this.type});

  final DateTime time;
  final _LicenseSessionDeadlineType type;

  String get warningTitle {
    switch (type) {
      case _LicenseSessionDeadlineType.expiration:
        return 'تنبيه الاشتراك';
      case _LicenseSessionDeadlineType.revalidation:
      case _LicenseSessionDeadlineType.offlineGrace:
        return 'تنبيه التحقق';
    }
  }

  String get warningMessage {
    switch (type) {
      case _LicenseSessionDeadlineType.expiration:
        return 'تبقى أقل من 5 دقائق على انتهاء الاشتراك. احفظ عملك وجهز التجديد.';
      case _LicenseSessionDeadlineType.revalidation:
        return 'تبقى أقل من 5 دقائق على فحص التفعيل. تأكد من اتصال الإنترنت لتستمر بدون انقطاع.';
      case _LicenseSessionDeadlineType.offlineGrace:
        return 'ستنتهي فترة السماح خلال أقل من 5 دقائق. اشبك الإنترنت لتستمر بالعمل.';
    }
  }
}
