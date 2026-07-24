import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:motamayez/services/security/security_native_bridge.dart';
import 'package:motamayez/services/security/security_trust_score.dart';

final class SecurityRuntimeService {
  SecurityRuntimeService._();

  static final SecurityRuntimeService instance = SecurityRuntimeService._();

  final SecurityNativeBridge _native = SecurityNativeBridge.instance;
  final Map<String, _IntegrityBaseline> _baselines = {};

  SecurityTrustScore _lastScore = SecurityTrustScore.fromSignals(const {});
  Timer? _timer;

  SecurityTrustScore get lastScore => _lastScore;

  Future<SecurityTrustScore> start({
    Duration interval = const Duration(minutes: 2),
  }) async {
    final first = await scanNow();
    _timer ??= Timer.periodic(interval, (_) {
      unawaited(scanNow());
    });
    return first;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<SecurityTrustScore> scanNow() async {
    final signals = <SecuritySignal>{..._native.readSignals()};
    if (await _sessionIntegrityFailed()) {
      signals.add(SecuritySignal.integrityFailure);
    }

    _lastScore = SecurityTrustScore.fromSignals(signals);
    return _lastScore;
  }

  Future<bool> _sessionIntegrityFailed() async {
    final paths = <String>{
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
        Platform.resolvedExecutable,
    };

    var failed = false;
    for (final path in paths) {
      final file = File(path);
      if (!await file.exists()) continue;

      final bytes = await file.readAsBytes();
      final sha = sha256.convert(bytes).toString();
      final nativeHash = _native.hash64(bytes)?.toRadixString(16);
      final baseline = _baselines[path];

      if (baseline == null) {
        _baselines[path] = _IntegrityBaseline(
          sha256Hex: sha,
          nativeHash64: nativeHash,
        );
        continue;
      }

      if (baseline.sha256Hex != sha || baseline.nativeHash64 != nativeHash) {
        failed = true;
      }
    }

    return failed;
  }

  String redactedSummary() {
    final score = _lastScore.toPublicMap();
    return jsonEncode({
      'score': score['score'],
      'requires_revalidation': score['requires_revalidation'],
      'blocks_new_login': score['blocks_new_login'],
      'signals': score['signals'],
    });
  }
}

class _IntegrityBaseline {
  const _IntegrityBaseline({
    required this.sha256Hex,
    required this.nativeHash64,
  });

  final String sha256Hex;
  final String? nativeHash64;
}
