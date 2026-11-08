#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>
#include <vector>

#include "app_links/app_links_plugin_c_api.h"
#include "flutter_window.h"
#include "utils.h"

// ──────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────

/// Write a wide-string message to the debug output (visible in DebugView
/// or the Visual Studio output window during development).
void DebugLog(const std::wstring& msg) {
  std::string narrow = Utf8FromUtf16(msg.c_str());
  OutputDebugStringA(narrow.c_str());
}

// ──────────────────────────────────────────────
// Custom URI protocol registration
// ──────────────────────────────────────────────

/// Register the `focusforge://` custom URI scheme in the Windows Registry
/// so that clicking a focusforge:// link in a browser launches this app.
/// Runs once per app launch (skips if already registered).
void RegisterFocusForgeProtocol() {
  // Only register if not already present
  HKEY hkTest;
  if (::RegOpenKeyExW(HKEY_CURRENT_USER,
                       L"Software\\Classes\\focusforge",
                       0, KEY_QUERY_VALUE, &hkTest) == ERROR_SUCCESS) {
    ::RegCloseKey(hkTest);
    return;
  }

  // Get the full path to this executable
  wchar_t exePath[MAX_PATH];
  DWORD pathLen = ::GetModuleFileNameW(nullptr, exePath, MAX_PATH);
  if (pathLen == 0 || pathLen >= MAX_PATH) return;

  HKEY hKey;

  // HKCU\Software\Classes\focusforge
  if (::RegCreateKeyExW(HKEY_CURRENT_USER,
                         L"Software\\Classes\\focusforge",
                         0, nullptr, REG_OPTION_NON_VOLATILE,
                         KEY_WRITE, nullptr, &hKey, nullptr) != ERROR_SUCCESS) {
    return;
  }

  // URL Protocol — required marker for custom URI schemes
  static const wchar_t kEmpty[] = L"";
  ::RegSetValueExW(hKey, L"URL Protocol", 0, REG_SZ,
                   reinterpret_cast<const BYTE*>(kEmpty),
                   static_cast<DWORD>(sizeof(wchar_t)));

  // Default description
  std::wstring description = L"URL:FocusForge Protocol";
  ::RegSetValueExW(hKey, nullptr, 0, REG_SZ,
                   reinterpret_cast<const BYTE*>(description.c_str()),
                   static_cast<DWORD>((description.length() + 1) * sizeof(wchar_t)));
  ::RegCloseKey(hKey);

  // HKCU\Software\Classes\focusforge\shell\open\command
  if (::RegCreateKeyExW(HKEY_CURRENT_USER,
                         L"Software\\Classes\\focusforge\\shell\\open\\command",
                         0, nullptr, REG_OPTION_NON_VOLATILE,
                         KEY_WRITE, nullptr, &hKey, nullptr) != ERROR_SUCCESS) {
    return;
  }

  // Command: "C:\path\to\app.exe" "%1"
  std::wstring command = std::wstring(L"\"") + exePath + L"\" \"%1\"";
  ::RegSetValueExW(hKey, nullptr, 0, REG_SZ,
                   reinterpret_cast<const BYTE*>(command.c_str()),
                   static_cast<DWORD>((command.length() + 1) * sizeof(wchar_t)));
  ::RegCloseKey(hKey);

  DebugLog(L"Registered focusforge:// protocol → " + command);
}

// ──────────────────────────────────────────────
// Single-instance protocol forwarding
// ──────────────────────────────────────────────

/// If the app was launched via a `focusforge://` URI AND an existing app
/// window is already running, forward the URI to that instance (using the
/// app_links plugin's C API), bring it to the foreground, and exit this
/// instance — preventing duplicate windows.
bool ForwardAppLinkToExistingInstance() {
  // Look for an existing Flutter window
  HWND hwnd = ::FindWindow(L"FLUTTER_RUNNER_WIN32_WINDOW", nullptr);
  if (!hwnd) return false;

  // SendAppLink (from app_links C API) reads argv[1] via GetCommandLineW()
  // and sends it as WM_COPYDATA with the correct message ID.
  // If there's no focusforge:// URI, it's a no-op.
  SendAppLink(hwnd);

  // After SendAppLink, we still don't know if anything was sent. Check
  // the actual command line for a focusforge:// URI to decide if we
  // should exit this instance.
  int argc;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  bool hasCustomUri = false;
  if (argv != nullptr) {
    for (int i = 1; i < argc; i++) {
      if (wcsncmp(argv[i], L"focusforge://", 13) == 0) {
        hasCustomUri = true;
        break;
      }
    }
    ::LocalFree(argv);
  }

  if (!hasCustomUri) return false;

  // Bring the existing window to the foreground
  WINDOWPLACEMENT place = { sizeof(WINDOWPLACEMENT) };
  ::GetWindowPlacement(hwnd, &place);
  switch (place.showCmd) {
    case SW_SHOWMAXIMIZED:
      ::ShowWindow(hwnd, SW_SHOWMAXIMIZED);
      break;
    case SW_SHOWMINIMIZED:
      ::ShowWindow(hwnd, SW_RESTORE);
      break;
    default:
      ::ShowWindow(hwnd, SW_NORMAL);
      break;
  }
  ::SetWindowPos(hwnd, HWND_TOP, 0, 0, 0, 0,
                 SWP_SHOWWINDOW | SWP_NOSIZE | SWP_NOMOVE);
  ::SetForegroundWindow(hwnd);

  return true;  // URI forwarded — this instance should exit
}

// ──────────────────────────────────────────────
// Entry point
// ──────────────────────────────────────────────

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // Register the custom URI protocol (focusforge://) so the OS knows
  // to launch this app when that scheme is opened (e.g. from a browser
  // after an OAuth redirect).
  RegisterFocusForgeProtocol();

  // Parse command-line arguments
  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // If this instance was launched by a focusforge:// protocol activation
  // and an existing window is already running, forward the URI via
  // SendAppLink (from the app_links plugin C API) and exit.
  if (ForwardAppLinkToExistingInstance()) {
    ::CoUninitialize();
    return EXIT_SUCCESS;  // Existing instance will handle the URI
  }

  flutter::DartProject project(L"data");

  // Pass command-line arguments as Dart entrypoint arguments.
  // For cold start with a focusforge:// URI, the app_links plugin's
  // GetLink() reads argv[1] directly from GetCommandLineW(), so it
  // can pick up the URI without needing Dart entrypoint arguments.
  // We pass them anyway for any other Dart-level use.
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"fokus", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
