#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#if defined(__ANDROID__)
#include <sys/system_properties.h>
#endif

enum SecurityFlags : uint32_t {
  kRootOrAdmin = 1u << 0,
  kMagisk = 1u << 1,
  kFrida = 1u << 2,
  kXposed = 1u << 3,
  kSuspiciousProcess = 1u << 4,
  kDebugger = 1u << 5,
  kEmulator = 1u << 6,
  kDeveloperMode = 1u << 7,
  kUsbDebugging = 1u << 8,
  kRuntimeHooking = 1u << 12,
};

static bool file_exists(const char* path) {
  return access(path, F_OK) == 0;
}

static bool proc_file_contains(const char* path, const char* needle) {
  FILE* file = fopen(path, "r");
  if (!file) return false;

  char line[512];
  bool found = false;
  while (fgets(line, sizeof(line), file)) {
    if (strstr(line, needle)) {
      found = true;
      break;
    }
  }

  fclose(file);
  return found;
}

static int tracer_pid() {
  FILE* file = fopen("/proc/self/status", "r");
  if (!file) return 0;

  char line[256];
  int tracer = 0;
  while (fgets(line, sizeof(line), file)) {
    if (sscanf(line, "TracerPid:\t%d", &tracer) == 1) {
      break;
    }
  }

  fclose(file);
  return tracer;
}

static bool prop_equals(const char* key, const char* expected) {
#if defined(__ANDROID__)
  char value[PROP_VALUE_MAX] = {0};
  if (__system_property_get(key, value) <= 0) return false;
  return strcmp(value, expected) == 0;
#else
  (void)key;
  (void)expected;
  return false;
#endif
}

extern "C" __attribute__((visibility("default"))) uint32_t mot_security_snapshot() {
  uint32_t flags = 0;

  if (file_exists("/system/bin/su") ||
      file_exists("/system/xbin/su") ||
      file_exists("/sbin/su") ||
      file_exists("/vendor/bin/su") ||
      file_exists("/su/bin/su")) {
    flags |= kRootOrAdmin;
  }

  if (file_exists("/sbin/.magisk") ||
      file_exists("/data/adb/magisk") ||
      proc_file_contains("/proc/self/mounts", "magisk")) {
    flags |= kMagisk | kRootOrAdmin;
  }

  if (proc_file_contains("/proc/self/maps", "frida") ||
      proc_file_contains("/proc/self/maps", "gum-js-loop") ||
      proc_file_contains("/proc/self/maps", "linjector")) {
    flags |= kFrida | kRuntimeHooking;
  }

  if (proc_file_contains("/proc/self/maps", "xposed") ||
      proc_file_contains("/proc/self/maps", "edxp") ||
      proc_file_contains("/proc/self/maps", "lsposed")) {
    flags |= kXposed | kRuntimeHooking;
  }

  if (tracer_pid() > 0) {
    flags |= kDebugger | kRuntimeHooking;
  }

  if (prop_equals("ro.debuggable", "1")) {
    flags |= kDeveloperMode;
  }

  if (prop_equals("init.svc.adbd", "running") ||
      prop_equals("persist.sys.usb.config", "adb")) {
    flags |= kUsbDebugging;
  }

  if (prop_equals("ro.kernel.qemu", "1") ||
      prop_equals("ro.product.model", "sdk_gphone64_x86_64") ||
      prop_equals("ro.hardware", "goldfish") ||
      prop_equals("ro.hardware", "ranchu")) {
    flags |= kEmulator;
  }

  return flags;
}

extern "C" __attribute__((visibility("default"))) uint64_t mot_security_hash64(
    const uint8_t* data,
    intptr_t length) {
  if (!data || length <= 0) return 0;

  uint64_t hash = 1469598103934665603ull;
  for (intptr_t i = 0; i < length; ++i) {
    hash ^= data[i];
    hash *= 1099511628211ull;
  }
  return hash;
}
