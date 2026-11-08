#ifndef RUNNER_OCR_HANDLER_H_
#define RUNNER_OCR_HANDLER_H_

#include <flutter/binary_messenger.h>

/// Registers the native OCR platform channel handler.
/// Supported method:
///   - recognizeText(filePath: String) -> String
void RegisterOcrHandler(flutter::BinaryMessenger* messenger);

#endif  // RUNNER_OCR_HANDLER_H_
