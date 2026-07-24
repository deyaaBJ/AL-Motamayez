import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'package:motamayez/services/security/security_trust_score.dart';

typedef _SnapshotNative = Uint32 Function();
typedef _SnapshotDart = int Function();
typedef _HashNative = Uint64 Function(Pointer<Uint8>, IntPtr);
typedef _HashDart = int Function(Pointer<Uint8>, int);

final class SecurityNativeBridge {
  SecurityNativeBridge._();

  static final SecurityNativeBridge instance = SecurityNativeBridge._();

  DynamicLibrary? _library;
  _SnapshotDart? _snapshot;
  _HashDart? _hash64;
  bool _loaded = false;

  bool get isAvailable => _snapshot != null && _hash64 != null;

  Set<SecuritySignal> readSignals() {
    final snapshot = _loadSnapshot();
    if (snapshot == null) {
      return {SecuritySignal.nativeUnavailable};
    }

    final flags = snapshot();
    return {
      if ((flags & 1) != 0) SecuritySignal.rootOrAdmin,
      if ((flags & 2) != 0) SecuritySignal.magisk,
      if ((flags & 4) != 0) SecuritySignal.frida,
      if ((flags & 8) != 0) SecuritySignal.xposed,
      if ((flags & 16) != 0) SecuritySignal.suspiciousProcess,
      if ((flags & 32) != 0) SecuritySignal.debugger,
      if ((flags & 64) != 0) SecuritySignal.emulator,
      if ((flags & 128) != 0) SecuritySignal.developerMode,
      if ((flags & 256) != 0) SecuritySignal.usbDebugging,
      if ((flags & 512) != 0) SecuritySignal.signatureTampering,
      if ((flags & 1024) != 0) SecuritySignal.vmOrSandbox,
      if ((flags & 2048) != 0) SecuritySignal.dllInjection,
      if ((flags & 4096) != 0) SecuritySignal.runtimeHooking,
    };
  }

  int? hash64(Uint8List bytes) {
    final hash = _loadHash();
    if (hash == null) return null;

    final pointer = calloc<Uint8>(bytes.length);
    try {
      pointer.asTypedList(bytes.length).setAll(0, bytes);
      return hash(pointer, bytes.length);
    } finally {
      calloc.free(pointer);
    }
  }

  _SnapshotDart? _loadSnapshot() {
    _ensureLoaded();
    return _snapshot;
  }

  _HashDart? _loadHash() {
    _ensureLoaded();
    return _hash64;
  }

  void _ensureLoaded() {
    if (_loaded) return;
    _loaded = true;

    try {
      if (Platform.isAndroid) {
        _library = DynamicLibrary.open('libmotamayez_security.so');
      } else if (Platform.isWindows) {
        _library = DynamicLibrary.executable();
      } else {
        return;
      }

      _snapshot = _library!
          .lookupFunction<_SnapshotNative, _SnapshotDart>(
            'mot_security_snapshot',
          );
      _hash64 = _library!
          .lookupFunction<_HashNative, _HashDart>('mot_security_hash64');
    } catch (_) {
      _snapshot = null;
      _hash64 = null;
    }
  }
}
