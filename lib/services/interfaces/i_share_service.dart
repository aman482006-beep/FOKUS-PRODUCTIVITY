/// Abstraction over share functionality for focus sessions and stats.
///
/// Implementations handle platform-specific sharing via the system share sheet.
/// This interface exists primarily to make sharing testable/mockable.
abstract class IShareService {
  /// Share the just-completed focus session with [durationLabel] and [sessionNumber].
  Future<void> shareSession({
    required String durationLabel,
    required int sessionNumber,
    int? streak,
  });

  /// Share overall focus stats (streak, total sessions, etc.).
  Future<void> shareStats();
}
