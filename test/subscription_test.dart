import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/features/tools/subscription_tracker_tool.dart';

void main() {
  // ════════════════════════════════════════════════════════════════
  // Subscription Model Tests
  // ════════════════════════════════════════════════════════════════

  group('Subscription', () {
    test('monthly cost for monthly billing', () {
      final sub = Subscription(
        id: '1',
        name: 'Netflix',
        cost: 15.99,
        isYearly: false,
        renewalDate: DateTime.now().add(const Duration(days: 15)),
      );
      expect(sub.monthlyCost, 15.99);
    });

    test('monthly cost for yearly billing', () {
      final sub = Subscription(
        id: '1',
        name: 'Netflix',
        cost: 191.88,
        isYearly: true,
        renewalDate: DateTime.now().add(const Duration(days: 180)),
      );
      expect(sub.monthlyCost, closeTo(15.99, 0.01));
    });

    test('yearly cost for yearly billing', () {
      final sub = Subscription(
        id: '1',
        name: 'Netflix',
        cost: 191.88,
        isYearly: true,
        renewalDate: DateTime.now().add(const Duration(days: 180)),
      );
      expect(sub.yearlyCost, 191.88);
    });

    test('yearly cost for monthly billing', () {
      final sub = Subscription(
        id: '1',
        name: 'Netflix',
        cost: 15.99,
        isYearly: false,
        renewalDate: DateTime.now().add(const Duration(days: 15)),
      );
      expect(sub.yearlyCost, closeTo(15.99 * 12, 0.01));
    });

    test('isDueSoon when renewal within 7 days', () {
      final sub = Subscription(
        id: '1',
        name: 'Netflix',
        cost: 15.99,
        isYearly: false,
        renewalDate: DateTime.now().add(const Duration(days: 5)),
      );
      expect(sub.isDueSoon, true);
    });

    test('isDueSoon when renewal more than 7 days away', () {
      final sub = Subscription(
        id: '1',
        name: 'Netflix',
        cost: 15.99,
        isYearly: false,
        renewalDate: DateTime.now().add(const Duration(days: 30)),
      );
      expect(sub.isDueSoon, false);
    });

    test('isOverdue when renewal date is in the past and active', () {
      final sub = Subscription(
        id: '1',
        name: 'Netflix',
        cost: 15.99,
        isYearly: false,
        renewalDate: DateTime.now().subtract(const Duration(days: 3)),
        isActive: true,
      );
      expect(sub.isOverdue, true);
    });

    test('isOverdue is false when inactive even if past date', () {
      final sub = Subscription(
        id: '1',
        name: 'Netflix',
        cost: 15.99,
        isYearly: false,
        renewalDate: DateTime.now().subtract(const Duration(days: 3)),
        isActive: false,
      );
      expect(sub.isOverdue, false);
    });

    test('toJson/fromJson roundtrip', () {
      final sub = Subscription(
        id: 'sub_1',
        name: 'Spotify',
        cost: 9.99,
        isYearly: false,
        renewalDate: DateTime(2026, 8, 15),
        category: 'Music',
        notes: 'Family plan',
        isActive: true,
      );
      final json = sub.toJson();
      final restored = Subscription.fromJson(json);
      expect(restored.id, 'sub_1');
      expect(restored.name, 'Spotify');
      expect(restored.cost, 9.99);
      expect(restored.isYearly, false);
      expect(restored.category, 'Music');
      expect(restored.notes, 'Family plan');
      expect(restored.isActive, true);
    });

    test('fromJson handles missing optional fields', () {
      final sub = Subscription.fromJson({
        'id': '1',
        'name': 'Test',
        'cost': 10.0,
        'isYearly': true,
        'renewalDate': '2026-12-01T00:00:00',
      });
      expect(sub.category, '');
      expect(sub.notes, '');
      expect(sub.isActive, true);
    });

    test('daysUntilRenewal returns absolute days', () {
      final sub = Subscription(
        id: '1',
        name: 'Past',
        cost: 10,
        isYearly: false,
        renewalDate: DateTime.now().subtract(const Duration(days: 5)),
      );
      expect(sub.daysUntilRenewal, 5);
    });

    test('yearly subscription due date edge case', () {
      final sub = Subscription(
        id: '1',
        name: 'Annual',
        cost: 120,
        isYearly: true,
        renewalDate: DateTime.now().add(const Duration(days: 1)),
      );
      expect(sub.isDueSoon, true);
      expect(sub.monthlyCost, closeTo(10.0, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════════
  // Aggregation Logic Tests (extracted from widget state)
  // ════════════════════════════════════════════════════════════════

  group('Subscription aggregation', () {
    double monthlyTotal(List<Subscription> subs) =>
        subs.where((s) => s.isActive).fold(0.0, (sum, s) => sum + s.monthlyCost);

    double yearlyTotal(List<Subscription> subs) =>
        subs.where((s) => s.isActive).fold(0.0, (sum, s) => sum + s.yearlyCost);

    int activeCount(List<Subscription> subs) =>
        subs.where((s) => s.isActive).length;

    int dueSoonCount(List<Subscription> subs) =>
        subs.where((s) => s.isActive && s.isDueSoon).length;

    Map<String, double> categoryBreakdown(List<Subscription> subs) {
      final map = <String, double>{};
      for (final s in subs.where((s) => s.isActive)) {
        map[s.category] = (map[s.category] ?? 0) + s.monthlyCost;
      }
      return map;
    }

    test('monthly total sums active subscriptions', () {
      final subs = [
        Subscription(id: '1', name: 'Netflix', cost: 15.99, isYearly: false, renewalDate: DateTime.now()),
        Subscription(id: '2', name: 'Spotify', cost: 9.99, isYearly: false, renewalDate: DateTime.now()),
        Subscription(id: '3', name: 'Old', cost: 99.99, isYearly: false, renewalDate: DateTime.now(), isActive: false),
      ];
      expect(monthlyTotal(subs), closeTo(25.98, 0.01));
    });

    test('yearly total mixes yearly and monthly billing', () {
      final subs = [
        Subscription(id: '1', name: 'Netflix', cost: 15.99, isYearly: false, renewalDate: DateTime.now()),
        Subscription(id: '2', name: 'Adobe', cost: 239.88, isYearly: true, renewalDate: DateTime.now()),
      ];
      expect(yearlyTotal(subs), closeTo(15.99 * 12 + 239.88, 0.01));
    });

    test('active count excludes inactive', () {
      final subs = [
        Subscription(id: '1', name: 'A', cost: 10, isYearly: false, renewalDate: DateTime.now(), isActive: true),
        Subscription(id: '2', name: 'B', cost: 10, isYearly: false, renewalDate: DateTime.now(), isActive: false),
        Subscription(id: '3', name: 'C', cost: 10, isYearly: false, renewalDate: DateTime.now(), isActive: true),
      ];
      expect(activeCount(subs), 2);
    });

    test('due soon count works', () {
      final subs = [
        Subscription(id: '1', name: 'A', cost: 10, isYearly: false, renewalDate: DateTime.now().add(const Duration(days: 3))),
        Subscription(id: '2', name: 'B', cost: 10, isYearly: false, renewalDate: DateTime.now().add(const Duration(days: 30))),
      ];
      expect(dueSoonCount(subs), 1);
    });

    test('category breakdown groups by category', () {
      final subs = [
        Subscription(id: '1', name: 'Netflix', cost: 15.99, isYearly: false, renewalDate: DateTime.now(), category: 'Video'),
        Subscription(id: '2', name: 'Spotify', cost: 9.99, isYearly: false, renewalDate: DateTime.now(), category: 'Music'),
        Subscription(id: '3', name: 'YouTube', cost: 13.99, isYearly: false, renewalDate: DateTime.now(), category: 'Video'),
      ];
      final breakdown = categoryBreakdown(subs);
      expect(breakdown['Video'], closeTo(29.98, 0.01));
      expect(breakdown['Music'], closeTo(9.99, 0.01));
    });

    test('empty list returns zeros', () {
      expect(monthlyTotal([]), 0.0);
      expect(yearlyTotal([]), 0.0);
      expect(activeCount([]), 0);
      expect(dueSoonCount([]), 0);
      expect(categoryBreakdown([]), isEmpty);
    });
  });
}
