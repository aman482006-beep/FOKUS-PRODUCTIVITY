import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class WindowHelper {
  static String getActiveProcessName() {
    final hwnd = GetForegroundWindow();
    if (hwnd == 0) return 'unknown.exe';

    final pvProcessId = calloc<DWORD>();
    try {
      GetWindowThreadProcessId(hwnd, pvProcessId);
      final processId = pvProcessId.value;

      final hProcess = OpenProcess(
        PROCESS_QUERY_LIMITED_INFORMATION,
        FALSE,
        processId,
      );
      if (hProcess == 0) return 'unknown.exe';

      final lpImageFileName = calloc<Uint16>(MAX_PATH).cast<Utf16>();
      final lpcchLen = calloc<DWORD>()..value = MAX_PATH;
      try {
        if (QueryFullProcessImageName(hProcess, 0, lpImageFileName, lpcchLen) != 0) {
          final fullPath = lpImageFileName.toDartString();
          return fullPath.split(r'\').last.toLowerCase();
        }
      } finally {
        free(lpImageFileName);
        free(lpcchLen);
        CloseHandle(hProcess);
      }
    } finally {
      free(pvProcessId);
    }
    return 'unknown.exe';
  }

  static String getActiveWindowTitle() {
    final hwnd = GetForegroundWindow();
    if (hwnd == 0) return 'Unknown';

    final length = GetWindowTextLength(hwnd);
    if (length == 0) return 'Unknown';

    final buffer = calloc<Uint16>(length + 1).cast<Utf16>();
    try {
      if (GetWindowText(hwnd, buffer, length + 1) != 0) {
        return buffer.toDartString();
      }
    } finally {
      free(buffer);
    }
    return 'Unknown';
  }
}
