#include <windows.h>
#include <tlhelp32.h>
#include <stdint.h>
#include <wchar.h>

enum SecurityFlags : uint32_t {
  kRootOrAdmin = 1u << 0,
  kFrida = 1u << 2,
  kSuspiciousProcess = 1u << 4,
  kDebugger = 1u << 5,
  kVmOrSandbox = 1u << 10,
  kDllInjection = 1u << 11,
  kRuntimeHooking = 1u << 12,
};

static bool contains_i(const wchar_t* haystack, const wchar_t* needle) {
  if (!haystack || !needle) return false;
  wchar_t lower_haystack[MAX_PATH * 2] = {0};
  wchar_t lower_needle[MAX_PATH] = {0};
  wcsncpy_s(lower_haystack, haystack, _TRUNCATE);
  wcsncpy_s(lower_needle, needle, _TRUNCATE);
  _wcslwr_s(lower_haystack);
  _wcslwr_s(lower_needle);
  return wcsstr(lower_haystack, lower_needle) != nullptr;
}

static bool known_tool_process_running() {
  const wchar_t* tools[] = {
      L"frida", L"x64dbg", L"x32dbg", L"ollydbg", L"ida", L"ida64",
      L"ghidra", L"dnspy", L"cheatengine", L"processhacker", L"procmon"};

  HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot == INVALID_HANDLE_VALUE) return false;

  PROCESSENTRY32W entry = {0};
  entry.dwSize = sizeof(entry);
  bool found = false;
  if (Process32FirstW(snapshot, &entry)) {
    do {
      for (const wchar_t* tool : tools) {
        if (contains_i(entry.szExeFile, tool)) {
          found = true;
          break;
        }
      }
    } while (!found && Process32NextW(snapshot, &entry));
  }

  CloseHandle(snapshot);
  return found;
}

static bool suspicious_module_loaded() {
  const wchar_t* modules[] = {
      L"frida", L"dbghelp", L"scylla", L"detours", L"easyhook", L"cheatengine"};

  HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE, GetCurrentProcessId());
  if (snapshot == INVALID_HANDLE_VALUE) return false;

  MODULEENTRY32W entry = {0};
  entry.dwSize = sizeof(entry);
  bool found = false;
  if (Module32FirstW(snapshot, &entry)) {
    do {
      for (const wchar_t* module : modules) {
        if (contains_i(entry.szModule, module) || contains_i(entry.szExePath, module)) {
          found = true;
          break;
        }
      }
    } while (!found && Module32NextW(snapshot, &entry));
  }

  CloseHandle(snapshot);
  return found;
}

static bool vm_indicator_present() {
  wchar_t computer_name[MAX_COMPUTERNAME_LENGTH + 1] = {0};
  DWORD size = MAX_COMPUTERNAME_LENGTH + 1;
  if (GetComputerNameW(computer_name, &size)) {
    if (contains_i(computer_name, L"sandbox") || contains_i(computer_name, L"maltest")) {
      return true;
    }
  }
  return false;
}

extern "C" __declspec(dllexport) uint32_t mot_security_snapshot() {
  uint32_t flags = 0;

  if (IsDebuggerPresent()) {
    flags |= kDebugger | kRuntimeHooking;
  }

  BOOL remote_debugger = FALSE;
  CheckRemoteDebuggerPresent(GetCurrentProcess(), &remote_debugger);
  if (remote_debugger) {
    flags |= kDebugger | kRuntimeHooking;
  }

  if (known_tool_process_running()) {
    flags |= kSuspiciousProcess;
  }

  if (suspicious_module_loaded()) {
    flags |= kDllInjection | kRuntimeHooking;
  }

  if (vm_indicator_present()) {
    flags |= kVmOrSandbox;
  }

  return flags;
}

extern "C" __declspec(dllexport) uint64_t mot_security_hash64(
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
