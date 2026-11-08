import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/services/point_service.dart';

void main() {
  group('PointService', () {
    group('calculatePoints', () {
      test('base points only (0 minutes, 0 streak)', () {
        final points = PointService.calculatePoints(fokusMinutes: 0, currentStreak: 0);
        expect(points, 10); // base only
      });

      test('15-minute session with no streak', () {
        final points = PointService.calculatePoints(fokusMinutes: 15, currentStreak: 0);
        expect(points, 25); // 10 base + 15 minutes
      });

      test('25-minute session with 1-day streak', () {
        final points = PointService.calculatePoints(fokusMinutes: 25, currentStreak: 1);
        expect(points, 40); // 10 base + 25 min + 5 streak
      });

      test('60-minute session with 5-day streak', () {
        final points = PointService.calculatePoints(fokusMinutes: 60, currentStreak: 5);
        expect(points, 95); // 10 base + 60 min + 25 streak
      });

      test('streak bonus capped at 50', () {
        final points = PointService.calculatePoints(fokusMinutes: 0, currentStreak: 20);
        expect(points, 60); // 10 base + 0 min + 50 streak cap
      });

      test('streak bonus exceeds cap', () {
        final points = PointService.calculatePoints(fokusMinutes: 0, currentStreak: 100);
        expect(points, 60); // 10 base + 50 streak cap
      });

      test('streak of exactly 10 reaches cap', () {
        final points = PointService.calculatePoints(fokusMinutes: 0, currentStreak: 10);
        expect(points, 60); // 10 + 50
      });

      test('large fokus minutes', () {
        final points = PointService.calculatePoints(fokusMinutes: 120, currentStreak: 0);
        expect(points, 130); // 10 base + 120 min
      });
    });

    group('addNewSessionPoints', () {
      test('adds to existing total', () {
        final total = PointService.addNewSessionPoints(
          currentTotalPoints: 100,
          fokusMinutes: 25,
          currentStreak: 2,
        );
        expect(total, 145); // 100 + 10 base + 25 min + 10 streak
      });

      test('starting from zero', () {
        final total = PointService.addNewSessionPoints(
          currentTotalPoints: 0,
          fokusMinutes: 0,
          currentStreak: 0,
        );
        expect(total, 10); // just base
      });

      test('accumulates correctly over multiple sessions', () {
        var total = 0;
        total = PointService.addNewSessionPoints(
            currentTotalPoints: total, fokusMinutes: 25, currentStreak: 1);
        total = PointService.addNewSessionPoints(
            currentTotalPoints: total, fokusMinutes: 25, currentStreak: 2);
        total = PointService.addNewSessionPoints(
            currentTotalPoints: total, fokusMinutes: 25, currentStreak: 3);
        // Session 1: 10+25+5=40, Session 2: 10+25+10=45, Session 3: 10+25+15=50
        expect(total, 135);
      });
    });
  });
}
