/// Point calculation for the friends leaderboard.
///
/// Points are awarded when a focus session completes:
/// - Base: 10 points per session
/// - Time bonus: 1 point per minute focused
/// - Streak bonus: +5 points per day of streak (capped at +50)
class PointService {
  PointService._();

  /// Calculate points awarded for completing a focus session.
  static int calculatePoints({
    required int fokusMinutes,
    required int currentStreak,
  }) {
    int points = 10; // Base per session
    points += fokusMinutes; // 1 point per minute
    points += (currentStreak * 5).clamp(0, 50); // Streak bonus, capped at +50
    return points;
  }

  /// Calculate the total points after adding a new session's points.
  static int addNewSessionPoints({
    required int currentTotalPoints,
    required int fokusMinutes,
    required int currentStreak,
  }) {
    return currentTotalPoints +
        calculatePoints(
          fokusMinutes: fokusMinutes,
          currentStreak: currentStreak,
        );
  }
}
