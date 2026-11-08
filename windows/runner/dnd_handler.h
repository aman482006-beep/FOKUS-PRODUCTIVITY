#ifndef RUNNER_DND_HANDLER_H_
#define RUNNER_DND_HANDLER_H_

#include <flutter/binary_messenger.h>

/// Registers the Do-Not-Disturb (Focus Shield) platform channel handler.
///
/// Supports three methods:
///   - enableDoNotDisturb()    -> bool  (Windows registry: set QuietHoursEnabled=1)
///   - disableDoNotDisturb()   -> bool  (Windows registry: set QuietHoursEnabled=0)
///   - getNotificationState()  -> int   (Windows registry: read QuietHoursEnabled)
void RegisterDndHandler(flutter::BinaryMessenger* messenger);

#endif  // RUNNER_DND_HANDLER_H_
