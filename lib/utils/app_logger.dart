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
    message?.toString() ?? '',
    name: name,
    error: error,
    stackTrace: stackTrace,
  );
}
