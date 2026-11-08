#include "ocr_handler.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>
#include <windows.h>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Storage.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>

#include <string>
#include <memory>
#include <iostream>
#include <thread>

namespace {

// Helper to run OCR synchronously using WinRT .get() blocking
std::string DoOcrSync(const std::wstring& file_path) {
  try {
    // 1. Get storage file from path
    auto file = winrt::Windows::Storage::StorageFile::GetFileFromPathAsync(file_path).get();
    if (!file) {
      return "Error: Could not open file at path.";
    }

    // 2. Open file stream
    auto stream = file.OpenAsync(winrt::Windows::Storage::FileAccessMode::Read).get();
    if (!stream) {
      return "Error: Could not open stream for file.";
    }

    // 3. Decode bitmap
    auto decoder = winrt::Windows::Graphics::Imaging::BitmapDecoder::CreateAsync(stream).get();
    if (!decoder) {
      return "Error: Could not decode image.";
    }

    auto bitmap = decoder.GetSoftwareBitmapAsync().get();
    if (!bitmap) {
      return "Error: Could not retrieve software bitmap.";
    }

    // 4. Create OCR engine using user profile languages (fallback to system default)
    auto engine = winrt::Windows::Media::Ocr::OcrEngine::TryCreateFromUserProfileLanguages();
    if (!engine) {
      return "Error: Native Windows OCR Engine could not be created.";
    }

    // 5. Run OCR recognition
    auto ocr_result = engine.RecognizeAsync(bitmap).get();
    if (!ocr_result) {
      return "Error: OCR Recognition failed.";
    }

    // 6. Collect recognized text
    std::wstring recognized_text = ocr_result.Text().c_str();

    // Convert wide string (UTF-16) to UTF-8 for Flutter
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, &recognized_text[0], (int)recognized_text.size(), NULL, 0, NULL, NULL);
    std::string utf8_text(size_needed, 0);
    if (size_needed > 0) {
      WideCharToMultiByte(CP_UTF8, 0, &recognized_text[0], (int)recognized_text.size(), &utf8_text[0], size_needed, NULL, NULL);
    }
    return utf8_text;
  } catch (const winrt::hresult_error& ex) {
    std::wstring message = ex.message().c_str();
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, &message[0], (int)message.size(), NULL, 0, NULL, NULL);
    std::string utf8_message(size_needed, 0);
    if (size_needed > 0) {
      WideCharToMultiByte(CP_UTF8, 0, &message[0], (int)message.size(), &utf8_message[0], size_needed, NULL, NULL);
    }
    return "Windows OCR HRESULT Error: " + utf8_message;
  } catch (const std::exception& ex) {
    return std::string("C++ Standard Exception: ") + ex.what();
  } catch (...) {
    return "Unknown Native Exception during OCR.";
  }
}

} // namespace

void RegisterOcrHandler(flutter::BinaryMessenger* messenger) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "com.focusforge.ocr/engine",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const auto& method = call.method_name();

        if (method == "recognizeText") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!arguments) {
            result->Error("INVALID_ARGUMENTS", "Arguments must be a Map");
            return;
          }

          auto path_iter = arguments->find(flutter::EncodableValue("filePath"));
          if (path_iter == arguments->end()) {
            result->Error("INVALID_ARGUMENTS", "filePath parameter is missing");
            return;
          }

          const auto* file_path_val = std::get_if<std::string>(&path_iter->second);
          if (!file_path_val) {
            result->Error("INVALID_ARGUMENTS", "filePath must be a string");
            return;
          }

          std::string path_utf8 = *file_path_val;

          // Convert UTF-8 path to std::wstring for Windows API
          int size_needed = MultiByteToWideChar(CP_UTF8, 0, &path_utf8[0], (int)path_utf8.size(), NULL, 0);
          std::wstring wpath(size_needed, 0);
          if (size_needed > 0) {
            MultiByteToWideChar(CP_UTF8, 0, &path_utf8[0], (int)path_utf8.size(), &wpath[0], size_needed);
          }

          // Move the unique_ptr to a shared_ptr so we can pass it to the background thread safely
          std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>> shared_result = std::move(result);

          std::thread([wpath, shared_result]() {
            try {
              // Initialize WinRT on this background thread (MTA)
              winrt::init_apartment();

              std::string ocr_text = DoOcrSync(wpath);
              
              if (ocr_text.rfind("Error:", 0) == 0 || ocr_text.rfind("Windows OCR", 0) == 0) {
                shared_result->Error("OCR_FAILED", ocr_text);
              } else {
                shared_result->Success(flutter::EncodableValue(ocr_text));
              }
            } catch (const winrt::hresult_error& ex) {
              std::wstring message = ex.message().c_str();
              int size_needed = WideCharToMultiByte(CP_UTF8, 0, &message[0], (int)message.size(), NULL, 0, NULL, NULL);
              std::string utf8_message(size_needed, 0);
              if (size_needed > 0) {
                WideCharToMultiByte(CP_UTF8, 0, &message[0], (int)message.size(), &utf8_message[0], size_needed, NULL, NULL);
              }
              shared_result->Error("OCR_FAILED", "Windows OCR HRESULT Error: " + utf8_message);
            } catch (const std::exception& ex) {
              shared_result->Error("OCR_FAILED", std::string("C++ Standard Exception: ") + ex.what());
            } catch (...) {
              shared_result->Error("OCR_FAILED", "Unknown Native Exception during background OCR.");
            }
          }).detach();
        } else {
          result->NotImplemented();
        }
      });

  // Release ownership to keep the channel alive
  channel.release();
}
