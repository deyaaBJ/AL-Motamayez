import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

void appLog(
  Object? message, {
  String name = 'app',
  Object? error,
  StackTrace? stackTrace,
}) {
  if (kReleaseMode) return;

  developer.log(
    _redact(message?.toString() ?? ''),
    name: name,
    error: error == null ? null : _redact(error.toString()),
    stackTrace: stackTrace,
  );
}

String _redact(String value) {
  try {
    return value
        .replaceAllMapped(
          RegExp(
            r'(deviceId|deviceHash|fingerprint|token|signature|payload)[=:]\s*[^,\s}]+',
            caseSensitive: false,
          ),
          (match) => '${match.group(1)}=<redacted>',
        )
        .replaceAllMapped(
          RegExp(
            r'"(deviceId|deviceHash|fingerprint|token|signature|payload)"\s*:\s*"[^"]*"',
            caseSensitive: false,
          ),
          (match) => '"${match.group(1)}":"<redacted>"',
        );
  } catch (_) {
    return value;
  }
}
