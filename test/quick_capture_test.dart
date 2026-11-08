import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fokus/models/quick_capture_item.dart';
import 'package:fokus/core/providers.dart';

void main() {
  group('extractUrls', () {
    test('extracts a single URL from text', () {
      final urls = extractUrls('Check this out https://example.com/page');
      expect(urls, ['https://example.com/page']);
    });

    test('extracts multiple URLs from text', () {
      final urls = extractUrls(
        'First link: https://example.com\nSecond: https://test.org/path\nThird: https://sub.domain.co.uk?a=1&b=2',
      );
      expect(urls.length, 3);
      expect(urls[0], 'https://example.com');
      expect(urls[1], 'https://test.org/path');
      expect(urls[2], 'https://sub.domain.co.uk?a=1&b=2');
    });

    test('returns empty list when no URLs present', () {
      final urls = extractUrls('Just some plain text without links');
      expect(urls, []);
    });

    test('returns empty list for empty string', () {
      final urls = extractUrls('');
      expect(urls, []);
    });
  });

  group('QuickCaptureItem — new format (plural fields)', () {
    test('creates item with multiple links and images', () {
      final item = QuickCaptureItem(
        id: 'test-1',
        text: 'Look at these links: https://example.com and https://test.org',
        timestamp: DateTime(2026, 5, 26),
        linkUrls: ['https://example.com', 'https://test.org'],
        mediaPaths: ['/path/to/img1.png', '/path/to/img2.jpg'],
      );

      expect(item.linkUrls.length, 2);
      expect(item.mediaPaths.length, 2);
      expect(item.hasImages, true);
      expect(item.hasLinks, true);
    });

    test('serializes and deserializes with multiple links and images', () {
      final item = QuickCaptureItem(
        id: 'test-serial',
        text: 'Multi link test https://a.com and https://b.com',
        timestamp: DateTime(2026, 5, 26, 10, 30),
        linkUrls: ['https://a.com', 'https://b.com'],
        mediaPaths: ['/img/a.png', '/img/b.png', '/img/c.png'],
      );

      final json = item.toJson();
      expect(json['linkUrls'], isA<List>());
      expect((json['linkUrls'] as List).length, 2);
      expect(json['mediaPaths'], isA<List>());
      expect((json['mediaPaths'] as List).length, 3);

      final decoded = QuickCaptureItem.fromJson(json);
      expect(decoded.id, 'test-serial');
      expect(decoded.linkUrls, ['https://a.com', 'https://b.com']);
      expect(decoded.mediaPaths, ['/img/a.png', '/img/b.png', '/img/c.png']);
    });

    test('copyWith preserves multiple link URLs', () {
      final item = QuickCaptureItem(
        id: 'test-copy',
        text: 'Original text',
        timestamp: DateTime(2026, 5, 26),
        linkUrls: ['https://original.com'],
        mediaPaths: ['/img/original.png'],
      );

      final updated = item.copyWith(
        text: 'Updated text with https://new.com',
        linkUrls: ['https://new.com'],
        mediaPaths: ['/img/new.png'],
      );

      expect(updated.text, 'Updated text with https://new.com');
      expect(updated.linkUrls, ['https://new.com']);
      expect(updated.mediaPaths, ['/img/new.png']);
    });
  });

  group('QuickCaptureItem — backward compatibility (old singular format)', () {
    test('reads old single linkUrl from JSON', () {
      final json = {
        'id': 'old-link',
        'text': 'Old format link',
        'timestamp': '2026-05-26T10:00:00.000',
        'linkUrl': 'https://old-format.com/article',
        'mediaPaths': [],
        'isActioned': false,
      };

      final item = QuickCaptureItem.fromJson(json);
      expect(item.linkUrls, ['https://old-format.com/article']);
    });

    test('reads old single mediaPath from JSON', () {
      final json = {
        'id': 'old-img',
        'text': 'Old format image',
        'timestamp': '2026-05-26T10:00:00.000',
        'linkUrls': [],
        'mediaPath': '/old/path/image.png',
        'isActioned': false,
      };

      final item = QuickCaptureItem.fromJson(json);
      expect(item.mediaPaths, ['/old/path/image.png']);
    });

    test('reads both old linkUrl and old mediaPath simultaneously', () {
      final json = {
        'id': 'old-both',
        'text': 'Old format both',
        'timestamp': '2026-05-26T10:00:00.000',
        'linkUrl': 'https://old-link.com',
        'mediaPath': '/old/path/img.png',
        'isActioned': false,
      };

      final item = QuickCaptureItem.fromJson(json);
      expect(item.linkUrls, ['https://old-link.com']);
      expect(item.mediaPaths, ['/old/path/img.png']);
    });

    test('prefers new linkUrls over old linkUrl when both present', () {
      final json = {
        'id': 'mixed',
        'text': 'Mixed format',
        'timestamp': '2026-05-26T10:00:00.000',
        'linkUrls': ['https://new.com/link1', 'https://new.com/link2'],
        'linkUrl': 'https://old.com/ignored',
        'mediaPaths': [],
        'isActioned': false,
      };

      final item = QuickCaptureItem.fromJson(json);
      expect(item.linkUrls, ['https://new.com/link1', 'https://new.com/link2']);
    });

    test('prefers new mediaPaths over old mediaPath when both present', () {
      final json = {
        'id': 'mixed-img',
        'text': 'Mixed image format',
        'timestamp': '2026-05-26T10:00:00.000',
        'linkUrls': [],
        'mediaPaths': ['/new/img1.png', '/new/img2.png'],
        'mediaPath': '/old/img.png',
        'isActioned': false,
      };

      final item = QuickCaptureItem.fromJson(json);
      expect(item.mediaPaths, ['/new/img1.png', '/new/img2.png']);
    });

    test('ignores empty old fields', () {
      final json = {
        'id': 'empty-old',
        'text': 'Empty old fields',
        'timestamp': '2026-05-26T10:00:00.000',
        'linkUrl': '',
        'mediaPath': '',
        'isActioned': false,
      };

      final item = QuickCaptureItem.fromJson(json);
      expect(item.linkUrls, []);
      expect(item.mediaPaths, []);
    });

    test('handles JSON with neither old nor new link fields', () {
      final json = {
        'id': 'no-links',
        'text': 'No links at all https://auto-detected.com/path',
        'timestamp': '2026-05-26T10:00:00.000',
        'isActioned': false,
      };

      final item = QuickCaptureItem.fromJson(json);
      // The URL in the text should be auto-detected
      expect(item.linkUrls.isNotEmpty, true);
      expect(item.linkUrls[0], contains('auto-detected'));
    });
  });

  group('QuickCaptureItem — auto-detection of URLs from text', () {
    test('auto-detects URL from text when linkUrls is empty', () {
      final json = {
        'id': 'auto-detect',
        'text': 'Visit https://auto-detect.com/article for details',
        'timestamp': '2026-05-26T10:00:00.000',
        'linkUrls': [],
        'isActioned': false,
      };

      final item = QuickCaptureItem.fromJson(json);
      expect(item.linkUrls, ['https://auto-detect.com/article']);
    });

    test('does not duplicate URLs that are already in linkUrls', () {
      final json = {
        'id': 'no-dup',
        'text': 'Go to https://example.com/page',
        'timestamp': '2026-05-26T10:00:00.000',
        'linkUrls': ['https://example.com/page'],
        'isActioned': false,
      };

      final item = QuickCaptureItem.fromJson(json);
      expect(item.linkUrls, ['https://example.com/page']);
    });
  });

  group('QuickCaptureNotifier', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('addEntry with URLs auto-extracts them', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = QuickCaptureNotifier();

      // Wait for initial load to complete
      await prefs.setString('quick_capture_items', '[]');

      notifier.addEntry(
        'Check out https://example.com and https://test.org',
      );

      expect(notifier.state.length, 1);
      expect(notifier.state[0].linkUrls.length, 2);
      expect(notifier.state[0].linkUrls[0], 'https://example.com');
      expect(notifier.state[0].linkUrls[1], 'https://test.org');
    });

    test('addEntry with no URLs results in empty list', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = QuickCaptureNotifier();
      await prefs.setString('quick_capture_items', '[]');

      notifier.addEntry('Just a plain text note');

      expect(notifier.state.length, 1);
      expect(notifier.state[0].linkUrls, []);
    });

    test('addEntry with mediaPaths persists them', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = QuickCaptureNotifier();
      await prefs.setString('quick_capture_items', '[]');

      notifier.addEntry(
        'Note with images',
        mediaPaths: ['/img/one.png', '/img/two.png', '/img/three.png'],
      );

      expect(notifier.state.length, 1);
      expect(notifier.state[0].mediaPaths,
          ['/img/one.png', '/img/two.png', '/img/three.png']);
      expect(notifier.state[0].hasImages, true);
    });

    test('addEntry persists to SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = QuickCaptureNotifier();
      await prefs.setString('quick_capture_items', '[]');

      notifier.addEntry(
        'Persist test https://persist.com',
        mediaPaths: ['/img/persist.png'],
      );

      // Wait for the async _persist() to complete
      await Future.delayed(Duration.zero);

      // Read from SharedPreferences
      final raw = prefs.getString('quick_capture_items');
      expect(raw, isNotNull);

      // Parse the JSON string into a List
      final List<dynamic> list = jsonDecode(raw!) as List;
      expect(list.length, 1);

      final decoded = QuickCaptureItem.fromJson(
        list.first as Map<String, dynamic>,
      );
      expect(decoded.text, 'Persist test https://persist.com');
      expect(decoded.linkUrls, ['https://persist.com']);
      expect(decoded.mediaPaths, ['/img/persist.png']);
    });

    test('updateEntry re-extracts URLs from updated text', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = QuickCaptureNotifier();
      await prefs.setString('quick_capture_items', '[]');

      notifier.addEntry('Original note with https://original.com');

      final id = notifier.state[0].id;
      expect(notifier.state[0].linkUrls, ['https://original.com']);

      notifier.updateEntry(id, 'Updated with https://updated.com and https://another.com');

      expect(notifier.state[0].linkUrls,
          ['https://updated.com', 'https://another.com']);
    });

    test('updateEntry clears URLs when text has no URLs', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = QuickCaptureNotifier();
      await prefs.setString('quick_capture_items', '[]');

      notifier.addEntry('Had a link https://example.com');
      final id = notifier.state[0].id;

      notifier.updateEntry(id, 'No more links here');
      expect(notifier.state[0].linkUrls, []);
    });

    test('removeEntry works correctly', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = QuickCaptureNotifier();
      await prefs.setString('quick_capture_items', '[]');

      notifier.addEntry('First item');
      notifier.addEntry('Second item');
      notifier.addEntry('Third item');

      expect(notifier.state.length, 3);

      notifier.removeEntry(notifier.state[1].id);
      expect(notifier.state.length, 2);
    });

    test('toggleActioned works correctly', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = QuickCaptureNotifier();
      await prefs.setString('quick_capture_items', '[]');

      notifier.addEntry('Item to action');
      expect(notifier.state[0].isActioned, false);

      notifier.toggleActioned(notifier.state[0].id);
      expect(notifier.state[0].isActioned, true);

      notifier.toggleActioned(notifier.state[0].id);
      expect(notifier.state[0].isActioned, false);
    });

    test('clear removes all items', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = QuickCaptureNotifier();
      await prefs.setString('quick_capture_items', '[]');

      notifier.addEntry('Item 1');
      notifier.addEntry('Item 2');
      notifier.addEntry('Item 3');

      notifier.clear();
      expect(notifier.state, []);
    });
  });
}
