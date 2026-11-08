#include "dnd_handler.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>
#include <string>

// ──────────────────────────────────────────────
// Windows DND / Quiet Hours helpers
// ──────────────────────────────────────────────

namespace {

const wchar_t* kRegPath =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Notifications\\Settings";

/// Reads the current QuietHoursEnabled registry value.
/// Returns 0 if DND is off, 1 if on, or -1 on error.
int ReadQuietHoursState() {
  HKEY hKey;
  DWORD value = 0;
  DWORD size = sizeof(value);

  LONG result = ::RegOpenKeyExW(HKEY_CURRENT_USER, kRegPath, 0,
                                KEY_QUERY_VALUE, &hKey);
  if (result != ERROR_SUCCESS) return -1;

  result = ::RegQueryValueExW(hKey, L"QuietHoursEnabled", nullptr, nullptr,
                              reinterpret_cast<LPBYTE>(&value), &size);
  ::RegCloseKey(hKey);

  if (result != ERROR_SUCCESS) return -1;
  return static_cast<int>(value);
}

/// Writes the QuietHoursEnabled registry value.
/// value : 0 = off (notifications allowed), 1 = on (DND enabled).
bool WriteQuietHoursState(int value) {
  HKEY hKey;
  DWORD data = static_cast<DWORD>(value);

  LONG result = ::RegCreateKeyExW(HKEY_CURRENT_USER, kRegPath, 0, nullptr,
                                   REG_OPTION_NON_VOLATILE, KEY_SET_VALUE,
                                   nullptr, &hKey, nullptr);
  if (result != ERROR_SUCCESS) return false;

  result = ::RegSetValueExW(hKey, L"QuietHoursEnabled", 0, REG_DWORD,
                            reinterpret_cast<const BYTE*>(&data), sizeof(data));
  ::RegCloseKey(hKey);

  return result == ERROR_SUCCESS;
}

}  // anonymous namespace

// ──────────────────────────────────────────────
// Platform channel handler registration
// ──────────────────────────────────────────────

void RegisterDndHandler(flutter::BinaryMessenger* messenger) {
  // The channel name must match the Dart side
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "com.example.fokus/dnd",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const auto& method = call.method_name();

        if (method == "enableDoNotDisturb") {
          bool ok = WriteQuietHoursState(1);
          result->Success(flutter::EncodableValue(ok));
        } else if (method == "disableDoNotDisturb") {
          bool ok = WriteQuietHoursState(0);
          result->Success(flutter::EncodableValue(ok));
        } else if (method == "getNotificationState") {
          int state = ReadQuietHoursState();
          result->Success(flutter::EncodableValue(state));
        } else {
          result->NotImplemented();
        }
      });

  // The channel object is leaked intentionally — Flutter takes ownership
  // of the handler registration, and the channel must live for the lifetime
  // of the engine. Since the engine outlives the FlutterWindow, keeping
  // the channel alive via leak is safe.
  channel.release();
}
