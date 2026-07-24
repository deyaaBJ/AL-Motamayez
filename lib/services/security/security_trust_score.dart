import 'dart:math' as math;

enum SecuritySignal {
  nativeUnavailable,
  rootOrAdmin,
  magisk,
  frida,
  xposed,
  suspiciousProcess,
  debugger,
  emulator,
  developerMode,
  usbDebugging,
  signatureTampering,
  vmOrSandbox,
  dllInjection,
  integrityFailure,
  runtimeHooking,
}

final class SecurityTrustScore {
  const SecurityTrustScore({
    required this.score,
    required this.signals,
    required this.checkedAt,
  });

  final int score;
  final Set<SecuritySignal> signals;
  final DateTime checkedAt;

  bool get isTrusted => score >= 80;
  bool get requiresRevalidation => !_hasOnlyDevelopmentSignals && score < 80;
  bool get blocksNewLogin => _hasBlockingSignals && score < 45;
  bool get suspiciousRuntime => signals.isNotEmpty;

  bool get _hasOnlyDevelopmentSignals =>
      signals.isNotEmpty &&
      signals.every(
        (signal) =>
            signal == SecuritySignal.debugger ||
            signal == SecuritySignal.runtimeHooking ||
            signal == SecuritySignal.vmOrSandbox ||
            signal == SecuritySignal.dllInjection ||
            signal == SecuritySignal.nativeUnavailable,
      );

  bool get _hasBlockingSignals =>
      signals.contains(SecuritySignal.frida) ||
      signals.contains(SecuritySignal.xposed) ||
      signals.contains(SecuritySignal.signatureTampering) ||
      signals.contains(SecuritySignal.integrityFailure);

  Duration constrainOfflineGrace(Duration baseGrace) {
    if (score >= 90) return baseGrace;
    if (score >= 70) return _fraction(baseGrace, 0.5);
    if (score >= 45) return _fraction(baseGrace, 0.15);
    return Duration.zero;
  }

  Map<String, dynamic> toPublicMap() {
    return {
      'score': score,
      'requires_revalidation': requiresRevalidation,
      'blocks_new_login': blocksNewLogin,
      'signals': signals.map((signal) => signal.name).toList(growable: false),
      'checked_at': checkedAt.toIso8601String(),
    };
  }

  static SecurityTrustScore fromSignals(Set<SecuritySignal> signals) {
    final weights = <SecuritySignal, int>{
      SecuritySignal.nativeUnavailable: 10,
      SecuritySignal.rootOrAdmin: 25,
      SecuritySignal.magisk: 35,
      SecuritySignal.frida: 40,
      SecuritySignal.xposed: 35,
      SecuritySignal.suspiciousProcess: 25,
      SecuritySignal.debugger: 35,
      SecuritySignal.emulator: 20,
      SecuritySignal.developerMode: 10,
      SecuritySignal.usbDebugging: 15,
      SecuritySignal.signatureTampering: 45,
      SecuritySignal.vmOrSandbox: 15,
      SecuritySignal.dllInjection: 35,
      SecuritySignal.integrityFailure: 45,
      SecuritySignal.runtimeHooking: 40,
    };

    final penalty = signals.fold<int>(
      0,
      (total, signal) => total + (weights[signal] ?? 15),
    );
    return SecurityTrustScore(
      score: math.max(0, 100 - penalty),
      signals: Set<SecuritySignal>.unmodifiable(signals),
      checkedAt: DateTime.now(),
    );
  }

  static Duration _fraction(Duration duration, double factor) {
    return Duration(milliseconds: (duration.inMilliseconds * factor).round());
  }
}
