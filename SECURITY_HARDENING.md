# POS Offline Security Hardening

This app remains an offline-capable POS, so client-side controls are tamper-resistant, not tamper-proof. A determined attacker who can patch the binary can still bypass local checks. The goal is layered cost increase: signed license data, device binding, native runtime probes, session integrity checks, and progressive trust degradation.

## Runtime Flow

1. `SecurityRuntimeService` starts during activation checks and runs periodic scans.
2. Native FFI probes return a bitmask for debugger, Frida, Xposed, Magisk/root, emulator, suspicious tools, and injection indicators.
3. Dart computes a session integrity baseline for critical local binaries and asks native code to compute an independent hash64 over the same bytes.
4. `SecurityTrustScore` converts signals into a score from 0 to 100.
5. `LicenseStateManager` applies the score:
   - `>= 80`: normal offline policy.
   - `70..79`: valid license can run, but offline grace is reduced.
   - `45..69`: license requires revalidation; an already running session can continue where allowed.
   - `< 45`: new login is blocked until revalidation on a clean runtime.

## What This Prevents

- Accidental use on obviously rooted/debuggable/test environments.
- Simple Frida/Xposed/Magisk/debugger sessions that leave common process, module, mount, or tracer indicators.
- Basic post-start binary replacement on desktop.
- Some repackaging attempts through native library absence, changed executable integrity, and release minification/stripping.

## What This Makes Harder

- Patching one Dart boolean is no longer enough; the license decision also depends on native probes and trust score policy.
- Hooking has to hide from `/proc`, loaded module scans, debugger APIs, and periodic rescans.
- Offline grace abuse is narrowed when the runtime is suspicious.
- Production logs avoid leaking license payloads, signatures, device fingerprints, and verification internals.

## What Is Still Possible

- Full local bypass is still possible for a skilled attacker with binary patching and enough time.
- Native checks can be patched out if the attacker modifies both Flutter and native code.
- RSA verification is still implemented in Dart in this revision. To move it completely native, add BoringSSL/OpenSSL to Android and Windows builds and make native verification mandatory for every signed envelope.
- Android package signature verification from pure NDK is limited without passing app context or adding a platform channel/JNI helper. This layer currently treats missing native runtime attestation as suspicious, not as an absolute block.

## Release Builds

Use:

```powershell
.\tooling\build_android_release.ps1
.\tooling\build_windows_release.ps1
```

Android release enables R8/resource shrinking, native symbol stripping, and Flutter obfuscation with split debug info. Windows release enables Flutter obfuscation plus optimized MSVC release flags.
