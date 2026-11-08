class QuickCaptureItem {
  final String id;
  final String text;
  final DateTime timestamp;
  final List<String> linkUrls;
  final List<String> mediaPaths;
  final bool isActioned;

  const QuickCaptureItem({
    required this.id,
    required this.text,
    required this.timestamp,
    this.linkUrls = const [],
    this.mediaPaths = const [],
    this.isActioned = false,
  });

  bool get hasImages => mediaPaths.isNotEmpty;
  bool get hasLinks => linkUrls.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'linkUrls': linkUrls,
        'mediaPaths': mediaPaths,
        'isActioned': isActioned,
      };

  factory QuickCaptureItem.fromJson(Map<String, dynamic> json) {
    final textVal = json['text'] as String? ?? '';

    // Read linkUrls (new format) or fall back to single linkUrl (old format)
    List<String> urls = [];
    if (json['linkUrls'] != null) {
      urls = List<String>.from(json['linkUrls'] as List);
    } else if (json['linkUrl'] != null && (json['linkUrl'] as String).isNotEmpty) {
      urls = [json['linkUrl'] as String];
    }
    // Auto-detect any URLs in text not already in the list
    final urlRegExp = RegExp(r'https?:\/\/[^\s]+');
    final matches = urlRegExp.allMatches(textVal);
    for (final m in matches) {
      final found = m.group(0)!;
      if (!urls.contains(found)) {
        urls.add(found);
      }
    }

    // Read mediaPaths (new format) or fall back to single mediaPath (old format)
    List<String> paths = [];
    if (json['mediaPaths'] != null) {
      paths = List<String>.from(json['mediaPaths'] as List);
    } else if (json['mediaPath'] != null && (json['mediaPath'] as String).isNotEmpty) {
      paths = [json['mediaPath'] as String];
    }

    return QuickCaptureItem(
      id: json['id'] as String? ?? DateTime.now().toIso8601String(),
      text: textVal,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      linkUrls: urls,
      mediaPaths: paths,
      isActioned: json['isActioned'] as bool? ?? false,
    );
  }

  QuickCaptureItem copyWith({
    String? text,
    List<String>? linkUrls,
    List<String>? mediaPaths,
    bool? isActioned,
  }) =>
      QuickCaptureItem(
        id: id,
        text: text ?? this.text,
        timestamp: timestamp,
        linkUrls: linkUrls ?? this.linkUrls,
        mediaPaths: mediaPaths ?? this.mediaPaths,
        isActioned: isActioned ?? this.isActioned,
      );
}

/// Parse all URLs from a text string.
List<String> extractUrls(String text) {
  final urlRegExp = RegExp(r'https?:\/\/[^\s]+');
  return urlRegExp.allMatches(text).map((m) => m.group(0)!).toList();
}
