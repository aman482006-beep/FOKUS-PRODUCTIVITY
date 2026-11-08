import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/features/tools/net_worth_timeline_tool.dart';

void main() {
  // ════════════════════════════════════════════════════════════════
  // NetWorthEntry Model Tests
  // ════════════════════════════════════════════════════════════════

  group('NetWorthEntry', () {
    test('toJson/fromJson roundtrip for asset', () {
      final entry = NetWorthEntry(
        id: 'nw_1',
        label: 'Savings Account',
        amount: 500000,
        isAsset: true,
        note: 'Emergency fund',
        date: DateTime(2026, 3, 15),
      );
      final json = entry.toJson();
      final restored = NetWorthEntry.fromJson(json);
      expect(restored.id, 'nw_1');
      expect(restored.label, 'Savings Account');
      expect(restored.amount, 500000);
      expect(restored.isAsset, true);
      expect(restored.note, 'Emergency fund');
      expect(restored.date, DateTime(2026, 3, 15));
    });

    test('toJson/fromJson roundtrip for liability', () {
      final entry = NetWorthEntry(
        id: 'nw_2',
        label: 'Home Loan',
        amount: 2000000,
        isAsset: false,
        note: 'HDFC Bank',
      );
      final json = entry.toJson();
      final restored = NetWorthEntry.fromJson(json);
      expect(restored.id, 'nw_2');
      expect(restored.isAsset, false);
      expect(restored.amount, 2000000);
    });

    test('fromJson handles missing optional fields', () {
      final entry = NetWorthEntry.fromJson({
        'id': '1',
        'label': 'Test',
        'amount': 100,
        'isAsset': true,
        'date': '2026-01-01T00:00:00',
      });
      expect(entry.note, '');
    });

    test('default date is now', () {
      final entry = NetWorthEntry(
        id: '1',
        label: 'Test',
        amount: 100,
        isAsset: true,
      );
      expect(entry.date, isA<DateTime>());
    });
  });

  // ════════════════════════════════════════════════════════════════
  // NetWorthSnapshot Model Tests
  // ════════════════════════════════════════════════════════════════

  group('NetWorthSnapshot', () {
    test('toJson/fromJson roundtrip', () {
      final snap = NetWorthSnapshot(
        date: DateTime(2026, 6, 1),
        netWorth: 1500000,
        note: 'Promotion bonus',
      );
      final json = snap.toJson();
      final restored = NetWorthSnapshot.fromJson(json);
      expect(restored.date, DateTime(2026, 6, 1));
      expect(restored.netWorth, 1500000);
      expect(restored.note, 'Promotion bonus');
    });

    test('fromJson handles null note', () {
      final snap = NetWorthSnapshot.fromJson({
        'date': '2026-01-01T00:00:00',
        'netWorth': 500000,
      });
      expect(snap.note, isNull);
    });

    test('snapshot with null note serializes correctly', () {
      final snap = NetWorthSnapshot(
        date: DateTime(2026, 1, 1),
        netWorth: 500000,
      );
      final json = snap.toJson();
      expect(json['note'], isNull);
    });
  });

  // ════════════════════════════════════════════════════════════════
  // Aggregation Logic Tests (extracted from widget state)
  // ════════════════════════════════════════════════════════════════

  group('Net worth aggregation', () {
    double totalAssets(List<NetWorthEntry> entries) =>
        entries.where((e) => e.isAsset).fold(0.0, (s, e) => s + e.amount);

    double totalLiabilities(List<NetWorthEntry> entries) =>
        entries.where((e) => !e.isAsset).fold(0.0, (s, e) => s + e.amount);

    double netWorth(List<NetWorthEntry> entries) =>
        totalAssets(entries) - totalLiabilities(entries);

    test('positive net worth', () {
      final entries = [
        NetWorthEntry(id: '1', label: 'Savings', amount: 500000, isAsset: true, date: DateTime.now()),
        NetWorthEntry(id: '2', label: 'Stocks', amount: 300000, isAsset: true, date: DateTime.now()),
        NetWorthEntry(id: '3', label: 'Loan', amount: 200000, isAsset: false, date: DateTime.now()),
      ];
      expect(totalAssets(entries), 800000);
      expect(totalLiabilities(entries), 200000);
      expect(netWorth(entries), 600000);
    });

    test('negative net worth', () {
      final entries = [
        NetWorthEntry(id: '1', label: 'Savings', amount: 100000, isAsset: true, date: DateTime.now()),
        NetWorthEntry(id: '2', label: 'Home Loan', amount: 5000000, isAsset: false, date: DateTime.now()),
      ];
      expect(netWorth(entries), -4900000);
    });

    test('zero entries', () {
      expect(netWorth([]), 0.0);
    });

    test('only assets', () {
      final entries = [
        NetWorthEntry(id: '1', label: 'A', amount: 100, isAsset: true, date: DateTime.now()),
      ];
      expect(netWorth(entries), 100);
      expect(totalLiabilities(entries), 0);
    });

    test('only liabilities', () {
      final entries = [
        NetWorthEntry(id: '1', label: 'Debt', amount: 500, isAsset: false, date: DateTime.now()),
      ];
      expect(netWorth(entries), -500);
      expect(totalAssets(entries), 0);
    });

    test('snapshots sorted by date', () {
      final snapshots = [
        NetWorthSnapshot(date: DateTime(2026, 6, 1), netWorth: 100),
        NetWorthSnapshot(date: DateTime(2026, 3, 1), netWorth: 50),
        NetWorthSnapshot(date: DateTime(2026, 9, 1), netWorth: 200),
      ];
      snapshots.sort((a, b) => a.date.compareTo(b.date));
      expect(snapshots.first.netWorth, 50);
      expect(snapshots.last.netWorth, 200);
    });

    test('snapshot change calculation', () {
      final first = NetWorthSnapshot(date: DateTime(2026, 1, 1), netWorth: 100000);
      final last = NetWorthSnapshot(date: DateTime(2026, 6, 1), netWorth: 150000);
      final change = last.netWorth - first.netWorth;
      expect(change, 50000);
    });
  });
}
