import 'dart:math';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../shared/motion.dart' as motion;
import '../../shared/theme.dart';
import '../../services/storage_service.dart';

// ──────────────────────────────────────────────
// Data Model
// ──────────────────────────────────────────────

enum WhiteboardTool {
  selection,
  hand,
  rectangle,
  diamond,
  ellipse,
  arrow,
  line,
  text,
  triangle,
  cloud,
  star,
  freehand,
}

class WhiteboardElement {
  final String id;
  final WhiteboardTool type;
  Rect rect;
  Color strokeColor;
  Color fillColor;
  double strokeWidth;
  String? text;
  Offset? startPoint;
  Offset? endPoint;
  List<Offset>? points; // for freehand
  Uint8List? imageBytes;
  String? imageName;
  double rotation;
  double cornerRadius;

  WhiteboardElement({
    required this.id,
    required this.type,
    required this.rect,
    this.strokeColor = const Color(0xFF1E1E1E),
    this.fillColor = Colors.transparent,
    this.strokeWidth = 2.0,
    this.text,
    this.startPoint,
    this.endPoint,
    this.points,
    this.imageBytes,
    this.imageName,
    this.rotation = 0,
    this.cornerRadius = 0.0,
  });

  WhiteboardElement copyWith({
    Rect? rect,
    Color? strokeColor,
    Color? fillColor,
    double? strokeWidth,
    String? text,
    Offset? startPoint,
    Offset? endPoint,
    List<Offset>? points,
    double? rotation,
    double? cornerRadius,
  }) {
    return WhiteboardElement(
      id: id,
      type: type,
      rect: rect ?? this.rect,
      strokeColor: strokeColor ?? this.strokeColor,
      fillColor: fillColor ?? this.fillColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      text: text ?? this.text,
      startPoint: startPoint ?? this.startPoint,
      endPoint: endPoint ?? this.endPoint,
      points: points ?? (this.points != null ? List.from(this.points!) : null),
      imageBytes: imageBytes ?? this.imageBytes,
      imageName: imageName ?? this.imageName,
      rotation: rotation ?? this.rotation,
      cornerRadius: cornerRadius ?? this.cornerRadius,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'rect': {
        'left': rect.left,
        'top': rect.top,
        'width': rect.width,
        'height': rect.height,
      },
      'strokeColor': strokeColor.toARGB32(),
      'fillColor': fillColor.toARGB32(),
      'strokeWidth': strokeWidth,
      'text': text,
      'startPoint': startPoint != null ? {'dx': startPoint!.dx, 'dy': startPoint!.dy} : null,
      'endPoint': endPoint != null ? {'dx': endPoint!.dx, 'dy': endPoint!.dy} : null,
      'points': points?.map((o) => {'dx': o.dx, 'dy': o.dy}).toList(),
      'imageBytes': imageBytes != null ? base64Encode(imageBytes!) : null,
      'imageName': imageName,
      'rotation': rotation,
      'cornerRadius': cornerRadius,
    };
  }

  factory WhiteboardElement.fromMap(Map<String, dynamic> map) {
    final rectMap = map['rect'] as Map<String, dynamic>;
    final startPointMap = map['startPoint'] as Map<String, dynamic>?;
    final endPointMap = map['endPoint'] as Map<String, dynamic>?;
    final pointsList = map['points'] as List<dynamic>?;

    return WhiteboardElement(
      id: map['id'] as String,
      type: WhiteboardTool.values.firstWhere((e) => e.name == map['type'], orElse: () => WhiteboardTool.selection),
      rect: Rect.fromLTWH(
        (rectMap['left'] as num).toDouble(),
        (rectMap['top'] as num).toDouble(),
        (rectMap['width'] as num).toDouble(),
        (rectMap['height'] as num).toDouble(),
      ),
      strokeColor: Color(map['strokeColor'] as int),
      fillColor: Color(map['fillColor'] as int),
      strokeWidth: (map['strokeWidth'] as num).toDouble(),
      text: map['text'] as String?,
      startPoint: startPointMap != null ? Offset((startPointMap['dx'] as num).toDouble(), (startPointMap['dy'] as num).toDouble()) : null,
      endPoint: endPointMap != null ? Offset((endPointMap['dx'] as num).toDouble(), (endPointMap['dy'] as num).toDouble()) : null,
      points: pointsList?.map((p) {
        final pm = p as Map<String, dynamic>;
        return Offset((pm['dx'] as num).toDouble(), (pm['dy'] as num).toDouble());
      }).toList(),
      imageBytes: map['imageBytes'] != null ? base64Decode(map['imageBytes'] as String) : null,
      imageName: map['imageName'] as String?,
      rotation: (map['rotation'] as num?)?.toDouble() ?? 0.0,
      cornerRadius: (map['cornerRadius'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ──────────────────────────────────────────────
// Sketchy Rendering Helpers (rough.js style hand-drawn look)
// ──────────────────────────────────────────────

class _RoughRenderer {
  static Random _rand = Random(42);

  static double _noise(double amount) => (_rand.nextDouble() - 0.5) * amount;

  /// Draw a hand-drawn line from p1 to p2.
  static void sketchyLine(
    Canvas canvas,
    Offset p1,
    Offset p2, {
    required Color color,
    double strokeWidth = 2.0,
    double wobble = 1.5,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color
      ..strokeWidth = strokeWidth;

    final path = Path();
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = sqrt(dx * dx + dy * dy);
    final segments = max(4, dist ~/ 12);

    path.moveTo(p1.dx + _noise(wobble), p1.dy + _noise(wobble));

    for (int i = 1; i <= segments; i++) {
      final t = i / segments;
      path.lineTo(
        p1.dx + dx * t + _noise(wobble),
        p1.dy + dy * t + _noise(wobble),
      );
    }

    canvas.drawPath(path, paint);
  }

  /// Draw a sketchy polygon from a list of points (closed).
  static void _sketchyPolygon(
    Canvas canvas,
    List<Offset> points, {
    required Color strokeColor,
    required Color fillColor,
    double strokeWidth = 2.0,
  }) {
    if (points.length < 3) return;

    if (fillColor != Colors.transparent && (fillColor.a * 255.0).round() > 0) {
      final fillPaint = Paint()..color = fillColor..style = PaintingStyle.fill;
      final fillPath = Path()..moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        fillPath.lineTo(points[i].dx, points[i].dy);
      }
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
    }

    for (int i = 0; i < points.length; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      sketchyLine(canvas, p1, p2, color: strokeColor, strokeWidth: strokeWidth);
    }
  }

  /// Draw a sketchy rectangle.
  static void sketchyRect(
    Canvas canvas,
    Rect rect, {
    required Color strokeColor,
    required Color fillColor,
    double strokeWidth = 2.0,
  }) {
    if (fillColor != Colors.transparent && (fillColor.a * 255.0).round() > 0) {
      final fillPaint = Paint()..color = fillColor..style = PaintingStyle.fill;
      canvas.drawRect(rect, fillPaint);
    }

    final tl = rect.topLeft;
    final tr = rect.topRight;
    final br = rect.bottomRight;
    final bl = rect.bottomLeft;

    sketchyLine(canvas, tl, tr, color: strokeColor, strokeWidth: strokeWidth);
    sketchyLine(canvas, tr, br, color: strokeColor, strokeWidth: strokeWidth);
    sketchyLine(canvas, br, bl, color: strokeColor, strokeWidth: strokeWidth);
    sketchyLine(canvas, bl, tl, color: strokeColor, strokeWidth: strokeWidth);
  }

  /// Draw a sketchy rounded rectangle.
  static void sketchyRRect(
    Canvas canvas,
    Rect rect,
    double r, {
    required Color strokeColor,
    required Color fillColor,
    double strokeWidth = 2.0,
  }) {
    if (r <= 0) {
      sketchyRect(canvas, rect, strokeColor: strokeColor, fillColor: fillColor, strokeWidth: strokeWidth);
      return;
    }
    
    final clampedR = min(r, min(rect.width, rect.height) / 2);

    if (fillColor != Colors.transparent && (fillColor.a * 255.0).round() > 0) {
      final fillPaint = Paint()..color = fillColor..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(clampedR)), fillPaint);
    }

    // 1. Draw straight edges
    final topStart = Offset(rect.left + clampedR, rect.top);
    final topEnd = Offset(rect.right - clampedR, rect.top);
    sketchyLine(canvas, topStart, topEnd, color: strokeColor, strokeWidth: strokeWidth);

    final rightStart = Offset(rect.right, rect.top + clampedR);
    final rightEnd = Offset(rect.right, rect.bottom - clampedR);
    sketchyLine(canvas, rightStart, rightEnd, color: strokeColor, strokeWidth: strokeWidth);

    final bottomStart = Offset(rect.right - clampedR, rect.bottom);
    final bottomEnd = Offset(rect.left + clampedR, rect.bottom);
    sketchyLine(canvas, bottomStart, bottomEnd, color: strokeColor, strokeWidth: strokeWidth);

    final leftStart = Offset(rect.left, rect.bottom - clampedR);
    final leftEnd = Offset(rect.left, rect.top + clampedR);
    sketchyLine(canvas, leftStart, leftEnd, color: strokeColor, strokeWidth: strokeWidth);

    // 2. Draw sketchy corners (approximating 90-degree arcs)
    void drawCornerArc(Offset center, double startAngle, double endAngle) {
      final segments = 4;
      final path = Path();
      final startA = startAngle + _noise(0.05);
      path.moveTo(
        center.dx + clampedR * cos(startA) + _noise(0.8),
        center.dy + clampedR * sin(startA) + _noise(0.8),
      );
      for (int i = 1; i <= segments; i++) {
        final t = i / segments;
        final angle = startA + (endAngle - startA) * t;
        path.lineTo(
          center.dx + clampedR * cos(angle) + _noise(0.8),
          center.dy + clampedR * sin(angle) + _noise(0.8),
        );
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = strokeColor
        ..strokeWidth = strokeWidth;
      canvas.drawPath(path, paint);
    }

    // Top-Right corner (angle -pi/2 to 0)
    drawCornerArc(Offset(rect.right - clampedR, rect.top + clampedR), -pi / 2, 0);
    // Bottom-Right corner (angle 0 to pi/2)
    drawCornerArc(Offset(rect.right - clampedR, rect.bottom - clampedR), 0, pi / 2);
    // Bottom-Left corner (angle pi/2 to pi)
    drawCornerArc(Offset(rect.left + clampedR, rect.bottom - clampedR), pi / 2, pi);
    // Top-Left corner (angle pi to 3*pi/2)
    drawCornerArc(Offset(rect.left + clampedR, rect.top + clampedR), pi, 3 * pi / 2);
  }

  /// Draw a sketchy diamond.
  static void sketchyDiamond(
    Canvas canvas,
    Rect rect, {
    required Color strokeColor,
    required Color fillColor,
    double strokeWidth = 2.0,
  }) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final top = Offset(cx, cy - rect.height / 2);
    final right = Offset(cx + rect.width / 2, cy);
    final bottom = Offset(cx, cy + rect.height / 2);
    final left = Offset(cx - rect.width / 2, cy);

    _sketchyPolygon(canvas, [top, right, bottom, left],
        strokeColor: strokeColor, fillColor: fillColor, strokeWidth: strokeWidth);
  }

  /// Draw a sketchy ellipse.
  static void sketchyEllipse(
    Canvas canvas,
    Rect rect, {
    required Color strokeColor,
    required Color fillColor,
    double strokeWidth = 2.0,
  }) {
    if (fillColor != Colors.transparent && (fillColor.a * 255.0).round() > 0) {
      final fillPaint = Paint()..color = fillColor..style = PaintingStyle.fill;
      canvas.drawOval(rect, fillPaint);
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = strokeColor
      ..strokeWidth = strokeWidth;

    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final rx = rect.width / 2;
    final ry = rect.height / 2;
    final segments = max(8, (pi * max(rx, ry)) ~/ 8);

    final path = Path();
    final startAngle = _noise(0.1);
    path.moveTo(
      cx + rx * cos(startAngle) + _noise(0.8),
      cy + ry * sin(startAngle) + _noise(0.8),
    );

    for (int i = 1; i <= segments; i++) {
      final angle = startAngle + (2 * pi * i / segments);
      path.lineTo(
        cx + rx * cos(angle) + _noise(1.0),
        cy + ry * sin(angle) + _noise(1.0),
      );
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  /// Draw a sketchy arrow with arrowhead.
  static void sketchyArrow(
    Canvas canvas,
    Offset start,
    Offset end, {
    required Color strokeColor,
    double strokeWidth = 2.0,
  }) {
    sketchyLine(canvas, start, end, color: strokeColor, strokeWidth: strokeWidth);

    final angle = atan2(end.dy - start.dy, end.dx - start.dx);
    const headLen = 12.0;
    const headAngle = 0.45;

    final a1 = Offset(
      end.dx - headLen * cos(angle - headAngle),
      end.dy - headLen * sin(angle - headAngle),
    );
    final a2 = Offset(
      end.dx - headLen * cos(angle + headAngle),
      end.dy - headLen * sin(angle + headAngle),
    );

    final headPath = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(a1.dx, a1.dy)
      ..lineTo(a2.dx, a2.dy)
      ..close();

    final headPaint = Paint()..color = strokeColor..style = PaintingStyle.fill;
    canvas.drawPath(headPath, headPaint);

    final outlinePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(headPath, outlinePaint);
  }

  /// Draw a sketchy triangle.
  static void sketchyTriangle(
    Canvas canvas,
    Rect rect, {
    required Color strokeColor,
    required Color fillColor,
    double strokeWidth = 2.0,
  }) {
    final top = Offset(rect.center.dx, rect.top);
    final right = Offset(rect.right, rect.bottom);
    final left = Offset(rect.left, rect.bottom);
    _sketchyPolygon(canvas, [top, right, left],
        strokeColor: strokeColor, fillColor: fillColor, strokeWidth: strokeWidth);
  }

  /// Draw a sketchy cloud using overlapping sine bumps around an elliptical path.
  static void sketchyCloud(
    Canvas canvas,
    Rect rect, {
    required Color strokeColor,
    required Color fillColor,
    double strokeWidth = 2.0,
  }) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final rx = rect.width / 2;
    final ry = rect.height / 2;
    const numPoints = 24;
    const bumpCount = 6;

    // Build the cloud path points (computed once, shared for fill + stroke)
    List<Offset> _cloudPts() {
      final pts = <Offset>[];
      for (int i = 0; i <= numPoints; i++) {
        final angle = (2 * pi * i) / numPoints;
        double bump = 1.0;
        for (int k = 0; k < bumpCount; k++) {
          final bumpCenter = 2 * pi * k / bumpCount;
          double dist = (angle - bumpCenter);
          if (dist > pi) dist -= 2 * pi;
          if (dist < -pi) dist += 2 * pi;
          bump += 0.35 * exp(-dist * dist * 10);
        }
        final x = cx + rx * bump * cos(angle) + _noise(1.0);
        final y = cy + ry * bump * sin(angle) + _noise(1.0);
        pts.add(Offset(x, y));
      }
      return pts;
    }

    final pts = _cloudPts();

    if (fillColor != Colors.transparent && (fillColor.a * 255.0).round() > 0) {
      final fillPath = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < pts.length; i++) {
        fillPath.lineTo(pts[i].dx, pts[i].dy);
      }
      fillPath.close();
      final fillPaint = Paint()..color = fillColor..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = strokeColor
      ..strokeWidth = strokeWidth;

    final path = Path()..moveTo(pts[0].dx + _noise(0.5), pts[0].dy + _noise(0.5));
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx + _noise(0.5), pts[i].dy + _noise(0.5));
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  /// Draw a sketchy 5-pointed star.
  static void sketchyStar(
    Canvas canvas,
    Rect rect, {
    required Color strokeColor,
    required Color fillColor,
    double strokeWidth = 2.0,
  }) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final outerR = min(rect.width, rect.height) / 2;
    final innerR = outerR * 0.4;

    final points = <Offset>[];
    for (int i = 0; i < 10; i++) {
      final r = i % 2 == 0 ? outerR : innerR;
      final angle = -pi / 2 + (2 * pi * i) / 10;
      points.add(Offset(cx + r * cos(angle), cy + r * sin(angle)));
    }

    _sketchyPolygon(canvas, points,
        strokeColor: strokeColor, fillColor: fillColor, strokeWidth: strokeWidth);
  }

  /// Draw a sketchy freehand path through a list of points.
  static void sketchyFreehand(
    Canvas canvas,
    List<Offset> points, {
    required Color color,
    double strokeWidth = 2.0,
  }) {
    if (points.length < 2) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color
      ..strokeWidth = strokeWidth;

    final path = Path();
    path.moveTo(
      points[0].dx + _noise(0.8),
      points[0].dy + _noise(0.8),
    );

    for (int i = 1; i < points.length; i++) {
      path.lineTo(
        points[i].dx + _noise(0.8),
        points[i].dy + _noise(0.8),
      );
    }

    canvas.drawPath(path, paint);
  }
}

// ──────────────────────────────────────────────
// Whiteboard Painter
// ──────────────────────────────────────────────

class WhiteboardPainter extends CustomPainter {
  final List<WhiteboardElement> elements;
  final Set<String> selectedIds;
  final WhiteboardTool currentTool;
  final Offset? drawingStart;
  final Offset? drawingCurrent;
  final List<Offset>? freehandPoints;
  final Color strokeColor;
  final Color fillColor;
  final double strokeWidth;
  final Offset panOffset;
  final double scale;
  final Map<String, ui.Image> loadedImages;
  final Rect? marqueeRect;

  WhiteboardPainter({
    required this.elements,
    this.selectedIds = const {},
    required this.currentTool,
    this.drawingStart,
    this.drawingCurrent,
    this.freehandPoints,
    required this.strokeColor,
    required this.fillColor,
    required this.strokeWidth,
    this.panOffset = Offset.zero,
    this.scale = 1.0,
    this.loadedImages = const {},
    this.marqueeRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // White background
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF8F9FA));

    canvas.save();
    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(scale);

    _drawGrid(canvas, size);

    for (final element in elements) {
      canvas.save();
      if (element.rotation != 0) {
        final center = element.rect.center;
        canvas.translate(center.dx, center.dy);
        canvas.rotate(element.rotation);
        canvas.translate(-center.dx, -center.dy);
      }
      _drawElement(canvas, element);
      canvas.restore();

      if (currentTool != WhiteboardTool.hand && selectedIds.contains(element.id)) {
        _drawSelectionHandles(canvas, element.rect);
      }
    }

    // Draw in-progress shape
    if (drawingStart != null && drawingCurrent != null) {
      if (currentTool == WhiteboardTool.arrow) {
        _RoughRenderer.sketchyArrow(canvas, drawingStart!, drawingCurrent!,
            strokeColor: strokeColor, strokeWidth: strokeWidth);
      } else if (currentTool == WhiteboardTool.line) {
        _RoughRenderer.sketchyLine(canvas, drawingStart!, drawingCurrent!,
            color: strokeColor, strokeWidth: strokeWidth);
      } else if (currentTool == WhiteboardTool.freehand) {
        // Freehand is drawn via freehandPoints
      } else {
        final rect = Rect.fromPoints(drawingStart!, drawingCurrent!);
        switch (currentTool) {
          case WhiteboardTool.rectangle:
            _RoughRenderer.sketchyRRect(canvas, rect, 0.0,
                strokeColor: strokeColor, fillColor: fillColor, strokeWidth: strokeWidth);
          case WhiteboardTool.diamond:
            _RoughRenderer.sketchyDiamond(canvas, rect,
                strokeColor: strokeColor, fillColor: fillColor, strokeWidth: strokeWidth);
          case WhiteboardTool.ellipse:
            _RoughRenderer.sketchyEllipse(canvas, rect,
                strokeColor: strokeColor, fillColor: fillColor, strokeWidth: strokeWidth);
          case WhiteboardTool.triangle:
            _RoughRenderer.sketchyTriangle(canvas, rect,
                strokeColor: strokeColor, fillColor: fillColor, strokeWidth: strokeWidth);
          case WhiteboardTool.cloud:
            _RoughRenderer.sketchyCloud(canvas, rect,
                strokeColor: strokeColor, fillColor: fillColor, strokeWidth: strokeWidth);
          case WhiteboardTool.star:
            _RoughRenderer.sketchyStar(canvas, rect,
                strokeColor: strokeColor, fillColor: fillColor, strokeWidth: strokeWidth);
          case WhiteboardTool.text:
            _drawSelectionHandles(canvas, rect);
          default:
            break;
        }
      }
    }

    // Draw in-progress freehand path
    if (freehandPoints != null && freehandPoints!.length >= 2) {
      _RoughRenderer.sketchyFreehand(canvas, freehandPoints!,
          color: strokeColor, strokeWidth: strokeWidth);
    }

    // Draw marquee selection rect
    if (marqueeRect != null) {
      final normalizedRect = Rect.fromLTRB(
        min(marqueeRect!.left, marqueeRect!.right),
        min(marqueeRect!.top, marqueeRect!.bottom),
        max(marqueeRect!.left, marqueeRect!.right),
        max(marqueeRect!.top, marqueeRect!.bottom),
      );
      final fillPaint = Paint()
        ..color = const Color(0xFF1971C2).withAlpha(25)
        ..style = PaintingStyle.fill;
      canvas.drawRect(normalizedRect, fillPaint);
      final borderPaint = Paint()
        ..color = const Color(0xFF1971C2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRect(normalizedRect, borderPaint);

      // Corner dots on marquee
      final dotPaint = Paint()
        ..color = const Color(0xFF1971C2)
        ..style = PaintingStyle.fill;
      const dotSize = 4.0;
      for (final corner in [
        normalizedRect.topLeft,
        normalizedRect.topRight,
        normalizedRect.bottomLeft,
        normalizedRect.bottomRight,
      ]) {
        canvas.drawCircle(corner, dotSize, dotPaint);
      }
    }

    canvas.restore();
  }

  void _drawGrid(Canvas canvas, Size size) {
    const gridSize = 25.0;
    final visibleRect = Rect.fromLTWH(
      -panOffset.dx / scale,
      -panOffset.dy / scale,
      size.width / scale,
      size.height / scale,
    );

    final startX = (visibleRect.left / gridSize).floor() * gridSize;
    final startY = (visibleRect.top / gridSize).floor() * gridSize;
    final endX = visibleRect.right;
    final endY = visibleRect.bottom;

    final gridPaint = Paint()
      ..color = const Color(0xFFE8E8E8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (double x = startX; x <= endX; x += gridSize) {
      canvas.drawLine(Offset(x, visibleRect.top), Offset(x, endY), gridPaint);
    }
    for (double y = startY; y <= endY; y += gridSize) {
      canvas.drawLine(Offset(visibleRect.left, y), Offset(endX, y), gridPaint);
    }
  }

  void _drawElement(Canvas canvas, WhiteboardElement element) {
    switch (element.type) {
      case WhiteboardTool.rectangle:
        _RoughRenderer.sketchyRRect(canvas, element.rect, element.cornerRadius,
            strokeColor: element.strokeColor,
            fillColor: element.fillColor,
            strokeWidth: element.strokeWidth);
        _drawTextIfPresent(canvas, element);
      case WhiteboardTool.diamond:
        _RoughRenderer.sketchyDiamond(canvas, element.rect,
            strokeColor: element.strokeColor,
            fillColor: element.fillColor,
            strokeWidth: element.strokeWidth);
        _drawTextIfPresent(canvas, element);
      case WhiteboardTool.ellipse:
        _RoughRenderer.sketchyEllipse(canvas, element.rect,
            strokeColor: element.strokeColor,
            fillColor: element.fillColor,
            strokeWidth: element.strokeWidth);
        _drawTextIfPresent(canvas, element);
      case WhiteboardTool.triangle:
        _RoughRenderer.sketchyTriangle(canvas, element.rect,
            strokeColor: element.strokeColor,
            fillColor: element.fillColor,
            strokeWidth: element.strokeWidth);
        _drawTextIfPresent(canvas, element);
      case WhiteboardTool.cloud:
        _RoughRenderer.sketchyCloud(canvas, element.rect,
            strokeColor: element.strokeColor,
            fillColor: element.fillColor,
            strokeWidth: element.strokeWidth);
        _drawTextIfPresent(canvas, element);
      case WhiteboardTool.star:
        _RoughRenderer.sketchyStar(canvas, element.rect,
            strokeColor: element.strokeColor,
            fillColor: element.fillColor,
            strokeWidth: element.strokeWidth);
        _drawTextIfPresent(canvas, element);
      case WhiteboardTool.arrow:
        if (element.startPoint != null && element.endPoint != null) {
          _RoughRenderer.sketchyArrow(canvas, element.startPoint!, element.endPoint!,
              strokeColor: element.strokeColor, strokeWidth: element.strokeWidth);
        }
      case WhiteboardTool.line:
        if (element.startPoint != null && element.endPoint != null) {
          _RoughRenderer.sketchyLine(canvas, element.startPoint!, element.endPoint!,
              color: element.strokeColor, strokeWidth: element.strokeWidth);
        }
      case WhiteboardTool.freehand:
        if (element.points != null && element.points!.length >= 2) {
          _RoughRenderer.sketchyFreehand(canvas, element.points!,
              color: element.strokeColor, strokeWidth: element.strokeWidth);
        }
      case WhiteboardTool.text:
        _drawTextIfPresent(canvas, element);
      case WhiteboardTool.selection:
      case WhiteboardTool.hand:
        break;
    }

    // Draw image if this element has image bytes
    if (element.imageBytes != null) {
      final img = loadedImages[element.id];
      if (img != null) {
        _drawImageInRect(canvas, element.rect, img);
      } else {
        // Placeholder while loading
        final placeholderPaint = Paint()
          ..color = const Color(0xFFE8E8E8)
          ..style = PaintingStyle.fill;
        canvas.drawRect(element.rect, placeholderPaint);
        final borderPaint = Paint()
          ..color = const Color(0xFFCCCCCC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawRect(element.rect, borderPaint);
        // Photo icon
        final textStyle = GoogleFonts.architectsDaughter(
          fontSize: 12,
          color: const Color(0xFF888888),
        );
        final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
          textAlign: TextAlign.center,
          fontFamily: textStyle.fontFamily,
          fontSize: textStyle.fontSize,
        ))
          ..pushStyle(textStyle.getTextStyle())
          ..addText('📷');
        final para = pb.build()..layout(ui.ParagraphConstraints(width: element.rect.width));
        canvas.drawParagraph(para, Offset(
          element.rect.center.dx - para.width / 2,
          element.rect.center.dy - para.height / 2,
        ));
      }
    }
  }

  void _drawImageInRect(Canvas canvas, Rect rect, ui.Image image) {
    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();
    final scaleX = rect.width / imageWidth;
    final scaleY = rect.height / imageHeight;
    final fitScale = min(scaleX, scaleY);
    final fittedWidth = imageWidth * fitScale;
    final fittedHeight = imageHeight * fitScale;
    final dx = rect.left + (rect.width - fittedWidth) / 2;
    final dy = rect.top + (rect.height - fittedHeight) / 2;
    final srcRect = Rect.fromLTWH(0, 0, imageWidth, imageHeight);
    final dstRect = Rect.fromLTWH(dx, dy, fittedWidth, fittedHeight);
    canvas.drawImageRect(image, srcRect, dstRect, Paint());
  }

  void _drawTextIfPresent(Canvas canvas, WhiteboardElement element) {
    if (element.text != null && element.text!.isNotEmpty) {
      _drawTextInRect(canvas, element.rect, element.text!, element.strokeColor);
    }
  }

  void _drawTextInRect(Canvas canvas, Rect rect, String text, Color color) {
    final textStyle = GoogleFonts.architectsDaughter(
      fontSize: 16,
      color: color,
      height: 1.3,
    );
    final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.left,
      maxLines: null,
      fontFamily: textStyle.fontFamily,
      fontSize: textStyle.fontSize,
    ))
      ..pushStyle(textStyle.getTextStyle())
      ..addText(text);

    final constraints = ui.ParagraphConstraints(width: max(rect.width - 16, 20));
    final paragraph = paragraphBuilder.build()..layout(constraints);

    final dx = rect.left + 8;
    final dy = rect.top + 6;
    canvas.drawParagraph(paragraph, Offset(dx, dy));
  }

  void _drawSelectionHandles(Canvas canvas, Rect rect) {
    final handlePaint = Paint()
      ..color = const Color(0xFF1971C2)
      ..style = PaintingStyle.fill;
    final handleBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const handleSize = 8.0;
    final handles = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
      rect.centerLeft,
      rect.centerRight,
      rect.topCenter,
      rect.bottomCenter,
    ];

    for (final handle in handles) {
      final hRect = Rect.fromCenter(center: handle, width: handleSize, height: handleSize);
      canvas.drawRect(hRect, handlePaint);
      canvas.drawRect(hRect, handleBorder);
    }

    final borderPaint = Paint()
      ..color = const Color(0xFF1971C2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant WhiteboardPainter oldDelegate) => true;
}

// ──────────────────────────────────────────────
// Whiteboard Page
// ──────────────────────────────────────────────

class WhiteboardPage extends StatefulWidget {
  final VoidCallback onBack;

  const WhiteboardPage({super.key, required this.onBack});

  @override
  State<WhiteboardPage> createState() => _WhiteboardPageState();
}

class _WhiteboardPageState extends State<WhiteboardPage> {
  WhiteboardTool _currentTool = WhiteboardTool.selection;
  WhiteboardTool _lastActiveShape = WhiteboardTool.rectangle;
  Color _strokeColor = const Color(0xFF1E1E1E);
  Color _fillColor = const Color(0xFFFFD43B).withValues(alpha: 0.4);
  double _strokeWidth = 2.0;

  // Saved whiteboard status
  String? _currentWhiteboardId;
  String _currentWhiteboardName = "Untitled Whiteboard";
  String _currentWhiteboardUpdatedAt = "";

  final List<WhiteboardElement> _elements = [];
  final List<List<WhiteboardElement>> _undoStack = [];
  final List<List<WhiteboardElement>> _redoStack = [];

  Set<String> _selectedIds = {};
  Offset? _drawingStart;
  Offset? _drawingCurrent;
  List<Offset>? _freehandPoints;
  Offset? _dragStart;
  Offset? _dragCanvasStart;
  String? _draggingElementId;
  bool _isPanning = false;
  bool _isZooming = false;
  Map<String, Rect> _dragOriginalRects = {};
  Map<String, Offset?> _dragOriginalStartPoints = {};
  Map<String, Offset?> _dragOriginalEndPoints = {};
  Map<String, List<Offset>?> _dragOriginalPoints = {};
  Offset _lastTapPosition = Offset.zero;

  Offset _panOffset = Offset.zero;
  double _scale = 1.0;
  double _baseScale = 1.0;
  Offset _basePanOffset = Offset.zero;

  // ── Resize state ──
  bool _isResizing = false;
  int _resizeHandleIndex = -1;
  Rect? _originalRect;
  Offset? _originalStartPoint;
  Offset? _originalEndPoint;
  List<Offset>? _originalPoints;
  Offset? _resizeDragStart;

  bool _isExporting = false;
  int _activePointerCount = 0;

  // Multi-select & marquee
  Offset? _marqueeStart;
  Offset? _marqueeCurrent;

  // Aspect ratio lock for images
  bool _lockAspectRatio = true;

  // ── Snap to grid ──
  bool _snapToGrid = false;
  bool _showHistoryPanel = false;

  final Map<String, ui.Image> _loadedImages = {};

  int _idCounter = 0;

  // Keyboard shortcut mappings
  static final Map<LogicalKeyboardKey, WhiteboardTool> _keyToolMap = {
    LogicalKeyboardKey.keyV: WhiteboardTool.selection,
    LogicalKeyboardKey.keyH: WhiteboardTool.hand,
    LogicalKeyboardKey.keyR: WhiteboardTool.rectangle,
    LogicalKeyboardKey.keyD: WhiteboardTool.diamond,
    LogicalKeyboardKey.keyE: WhiteboardTool.ellipse,
    LogicalKeyboardKey.keyA: WhiteboardTool.arrow,
    LogicalKeyboardKey.keyL: WhiteboardTool.line,
    LogicalKeyboardKey.keyT: WhiteboardTool.text,
    LogicalKeyboardKey.keyG: WhiteboardTool.triangle,
    LogicalKeyboardKey.keyC: WhiteboardTool.cloud,
    LogicalKeyboardKey.keyS: WhiteboardTool.star,
    LogicalKeyboardKey.keyF: WhiteboardTool.freehand,
  };

  @override
  void dispose() {
    for (final img in _loadedImages.values) {
      img.dispose();
    }
    _loadedImages.clear();

    super.dispose();
  }

  // ── Undo / Redo ──
  void _saveState() {
    _undoStack.add(_elements.map((e) => e.copyWith()).toList());
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_elements.map((e) => e.copyWith()).toList());
    final prev = _undoStack.removeLast();
    setState(() {
      _elements
        ..clear()
        ..addAll(prev);
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_elements.map((e) => e.copyWith()).toList());
    final next = _redoStack.removeLast();
    setState(() {
      _elements
        ..clear()
        ..addAll(next);
    });
  }

  String _nextId() => 'el_${++_idCounter}';

  void _updateSelectedStrokeColor(Color color) {
    if (_selectedIds.isEmpty) return;
    _saveState();
    setState(() {
      for (final id in _selectedIds) {
        final idx = _elements.indexWhere((e) => e.id == id);
        if (idx >= 0) {
          _elements[idx] = _elements[idx].copyWith(strokeColor: color);
        }
      }
    });
  }

  void _updateSelectedFillColor(Color color) {
    if (_selectedIds.isEmpty) return;
    _saveState();
    setState(() {
      for (final id in _selectedIds) {
        final idx = _elements.indexWhere((e) => e.id == id);
        if (idx >= 0) {
          _elements[idx] = _elements[idx].copyWith(fillColor: color);
        }
      }
    });
  }

  void _updateSelectedStrokeWidth(double width) {
    if (_selectedIds.isEmpty) return;
    _saveState();
    setState(() {
      for (final id in _selectedIds) {
        final idx = _elements.indexWhere((e) => e.id == id);
        if (idx >= 0) {
          _elements[idx] = _elements[idx].copyWith(strokeWidth: width);
        }
      }
    });
  }

  IconData _getShapeIcon(WhiteboardTool tool) {
    switch (tool) {
      case WhiteboardTool.rectangle:
        return Icons.crop_square_rounded;
      case WhiteboardTool.diamond:
        return Icons.diamond_outlined;
      case WhiteboardTool.ellipse:
        return Icons.circle_outlined;
      case WhiteboardTool.arrow:
        return Icons.arrow_forward_rounded;
      case WhiteboardTool.line:
        return Icons.show_chart_rounded;
      case WhiteboardTool.triangle:
        return Icons.change_history;
      case WhiteboardTool.cloud:
        return Icons.cloud_queue;
      case WhiteboardTool.star:
        return Icons.star_border;
      default:
        return Icons.crop_square_rounded;
    }
  }

  double _calculateTextHeight(String text, double width, Color color) {
    final textStyle = GoogleFonts.architectsDaughter(
      fontSize: 16,
      color: color,
      height: 1.3,
    );
    final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.left,
      maxLines: null,
      fontFamily: textStyle.fontFamily,
      fontSize: textStyle.fontSize,
    ))
      ..pushStyle(textStyle.getTextStyle())
      ..addText(text);

    final constraints = ui.ParagraphConstraints(width: max(width - 16, 20));
    final paragraph = paragraphBuilder.build()..layout(constraints);
    return paragraph.height + 12; // 12 for padding (top 6 + bottom 6)
  }

  void _adjustTextElementHeight(WhiteboardElement element) {
    if (element.text == null || element.text!.isEmpty) return;
    final h = _calculateTextHeight(element.text!, element.rect.width, element.strokeColor);
    element.rect = Rect.fromLTWH(element.rect.left, element.rect.top, element.rect.width, h);
  }

  void _revertDraggedElements() {
    setState(() {
      for (final el in _elements) {
        if (_dragOriginalRects.containsKey(el.id)) {
          el.rect = _dragOriginalRects[el.id]!;
          el.startPoint = _dragOriginalStartPoints[el.id];
          el.endPoint = _dragOriginalEndPoints[el.id];
          el.points = _dragOriginalPoints[el.id];
        }
      }
    });
  }

  Widget _buildRightPropertiesPanel(ThemeTokens tokens) {
    if (_currentTool == WhiteboardTool.hand) {
      return const SizedBox.shrink();
    }
    WhiteboardElement? selectedEl;
    if (_selectedIds.length == 1) {
      for (final e in _elements) {
        if (e.id == _selectedIds.first) {
          selectedEl = e;
          break;
        }
      }
    }

    if (selectedEl == null || selectedEl.type != WhiteboardTool.rectangle) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 220,
      margin: const EdgeInsets.only(left: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.rounded_corner_rounded, size: 16, color: tokens.textPrimary),
              const SizedBox(width: 8),
              Text(
                'Rectangle Options',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Corner Roundness',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: tokens.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    activeTrackColor: const Color(0xFF1971C2),
                    inactiveTrackColor: const Color(0xFFDDDDDD),
                    thumbColor: const Color(0xFF1971C2),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: selectedEl.cornerRadius,
                    min: 0.0,
                    max: 40.0,
                    onChanged: (v) {
                      _saveState();
                      setState(() {
                        selectedEl!.cornerRadius = v;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${selectedEl.cornerRadius.round()}px',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF555555),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Hit testing ──
  WhiteboardElement? _elementAt(Offset point) {
    for (int i = _elements.length - 1; i >= 0; i--) {
      final el = _elements[i];
      switch (el.type) {
        case WhiteboardTool.arrow:
        case WhiteboardTool.line:
          if (el.startPoint != null && el.endPoint != null) {
            if (_distanceToLine(point, el.startPoint!, el.endPoint!) < 10) return el;
          }
        case WhiteboardTool.freehand:
          if (el.points != null && el.points!.length >= 2) {
            for (int j = 0; j < el.points!.length - 1; j++) {
              if (_distanceToLine(point, el.points![j], el.points![j + 1]) < 10) return el;
            }
          }
        default:
          if (el.rect.contains(point)) return el;
      }
    }
    return null;
  }

  double _distanceToLine(Offset point, Offset start, Offset end) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = dx * dx + dy * dy;
    if (length == 0) return (point - start).distance;
    final t = ((point.dx - start.dx) * dx + (point.dy - start.dy) * dy) / length;
    final clamped = t.clamp(0.0, 1.0);
    final closest = Offset(start.dx + clamped * dx, start.dy + clamped * dy);
    return (point - closest).distance;
  }

  // ── Coordinate helpers ──
  Offset _screenToCanvas(Offset screenPt) => Offset(
        (screenPt.dx - _panOffset.dx) / _scale,
        (screenPt.dy - _panOffset.dy) / _scale,
      );

  bool _isAltPressed() => HardwareKeyboard.instance.isAltPressed;

  // ── Canvas interaction ──
  void _onScaleStart(ScaleStartDetails details) {
    _isPanning = false;
    _isZooming = false;
    _dragOriginalRects.clear();
    _dragOriginalStartPoints.clear();
    _dragOriginalEndPoints.clear();
    _dragOriginalPoints.clear();

    for (final el in _elements) {
      _dragOriginalRects[el.id] = el.rect;
      _dragOriginalStartPoints[el.id] = el.startPoint;
      _dragOriginalEndPoints[el.id] = el.endPoint;
      _dragOriginalPoints[el.id] = el.points != null ? List.from(el.points!) : null;
    }

    final localPos = _screenToCanvas(details.localFocalPoint);
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    if (details.pointerCount > 1) {
      _isPanning = true;
      _dragCanvasStart = details.localFocalPoint;
      _baseScale = _scale;
      _basePanOffset = _panOffset;
      return;
    }

    if (_isAltPressed()) {
      _isPanning = true;
      _dragCanvasStart = details.localFocalPoint;
      return;
    }

    if (_currentTool == WhiteboardTool.hand) {
      _isPanning = true;
      _dragCanvasStart = details.localFocalPoint;
      return;
    }

    if (_currentTool == WhiteboardTool.selection) {
      // Prioritize checking selection handles of currently selected elements
      for (final id in _selectedIds) {
        final elementsWithId = _elements.where((e) => e.id == id);
        if (elementsWithId.isNotEmpty) {
          final el = elementsWithId.first;
          final handleIndex = _handleAt(localPos, el.rect);
          if (handleIndex >= 0) {
            _saveState();
            setState(() {
              _draggingElementId = el.id;
              _isResizing = true;
              _resizeHandleIndex = handleIndex;
              _originalRect = el.rect;
              _originalStartPoint = el.startPoint;
              _originalEndPoint = el.endPoint;
              _originalPoints =
                  el.points != null ? List.from(el.points!) : null;
              _resizeDragStart = localPos;
            });
            return;
          }
        }
      }

      final hit = _elementAt(localPos);
      if (hit != null) {
        _saveState();
        final handleIndex = _handleAt(localPos, hit.rect);
        setState(() {
          if (isShift) {
            // Toggle selection
            if (_selectedIds.contains(hit.id)) {
              _selectedIds = Set.from(_selectedIds)..remove(hit.id);
            } else {
              _selectedIds = Set.from(_selectedIds)..add(hit.id);
            }
            // If multiple selected, drag all
            if (_selectedIds.length >= 2) {
              _draggingElementId = hit.id;
              _dragStart = localPos;
            } else if (_selectedIds.length == 1) {
              final singleId = _selectedIds.first;
              final singleEl = _elements.firstWhere((e) => e.id == singleId);
              final singleHandle = _handleAt(localPos, singleEl.rect);
              _draggingElementId = singleId;
              if (singleHandle >= 0) {
                _isResizing = true;
                _resizeHandleIndex = singleHandle;
                _originalRect = singleEl.rect;
                _originalStartPoint = singleEl.startPoint;
                _originalEndPoint = singleEl.endPoint;
                _originalPoints =
                    singleEl.points != null ? List.from(singleEl.points!) : null;
                _resizeDragStart = localPos;
              } else {
                _dragStart = localPos;
              }
            }
          } else {
            if (!_selectedIds.contains(hit.id)) {
              _selectedIds = {hit.id};
            }
            _draggingElementId = hit.id;
            if (handleIndex >= 0) {
              _isResizing = true;
              _resizeHandleIndex = handleIndex;
              _originalRect = hit.rect;
              _originalStartPoint = hit.startPoint;
              _originalEndPoint = hit.endPoint;
              _originalPoints =
                  hit.points != null ? List.from(hit.points!) : null;
              _resizeDragStart = localPos;
            } else {
              _dragStart = localPos;
            }
          }
        });
        return;
      }
      // Click on empty canvas — start marquee or clear selection
      setState(() {
        if (!isShift) {
          _selectedIds = {};
        }
        _marqueeStart = localPos;
        _marqueeCurrent = localPos;
      });
      return;
    }

    if (_currentTool == WhiteboardTool.freehand) {
      _freehandPoints = [localPos];
    }

    setState(() {
      final snapped = _snapToGridValue(localPos);
      _drawingStart = snapped;
      _drawingCurrent = snapped;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final isZoomGesture = details.pointerCount > 1 || (details.scale - 1.0).abs() > 0.001;

    if (isZoomGesture) {
      if (!_isZooming) {
        _isZooming = true;
        _isPanning = false;
        _baseScale = _scale;
        _basePanOffset = _panOffset;
        _dragCanvasStart = details.localFocalPoint;

        // Revert any drawing or modifications started in _onScaleStart
        _revertDraggedElements();
        setState(() {
          _drawingStart = null;
          _drawingCurrent = null;
          _freehandPoints = null;
          _marqueeStart = null;
          _marqueeCurrent = null;
          _draggingElementId = null;
          _isResizing = false;
          _resizeHandleIndex = -1;
        });
      }

      setState(() {
        _scale = (_baseScale * details.scale).clamp(0.3, 3.0);
        final focalPoint = details.localFocalPoint;
        _panOffset = focalPoint - (_dragCanvasStart! - _basePanOffset) * (_scale / _baseScale);
      });
      return;
    }

    if (_isPanning) {
      setState(() {
        _panOffset += details.localFocalPoint - _dragCanvasStart!;
        _dragCanvasStart = details.localFocalPoint;
      });
      return;
    }

    final localPos = _screenToCanvas(details.localFocalPoint);

    if (_currentTool == WhiteboardTool.selection) {
      if (_isResizing && _draggingElementId != null) {
        final delta = localPos - _resizeDragStart!;
        final el = _elements.firstWhere((e) => e.id == _draggingElementId);
        final hasImage = el.imageBytes != null;
        final aspectRatio = hasImage && _lockAspectRatio
            ? (_originalRect!.width / _originalRect!.height)
            : null;
        final newRect = _computeResizedRect(
            _originalRect!, _resizeHandleIndex, delta,
            aspectRatio: aspectRatio);
        setState(() {
          if (el.type == WhiteboardTool.text && el.text != null) {
            final h = _calculateTextHeight(el.text!, newRect.width, el.strokeColor);
            el.rect = Rect.fromLTWH(newRect.left, newRect.top, newRect.width, h);
          } else {
            el.rect = newRect;
            if (el.startPoint != null && _originalStartPoint != null) {
              el.startPoint = _scalePoint(
                  _originalStartPoint!, _originalRect!, newRect);
            }
            if (el.endPoint != null && _originalEndPoint != null) {
              el.endPoint = _scalePoint(
                  _originalEndPoint!, _originalRect!, newRect);
            }
            if (el.points != null && _originalPoints != null) {
              el.points = _originalPoints!
                  .map((p) => _scalePoint(p, _originalRect!, newRect))
                  .toList();
            }
          }
        });
        return;
      }
      if (_draggingElementId != null) {
        final delta = localPos - _dragStart!;
        setState(() {
          // Move all selected elements
          for (final id in _selectedIds) {
            final e = _elements.firstWhere((el) => el.id == id);
            e.rect = e.rect.shift(delta);
            if (e.startPoint != null) e.startPoint = e.startPoint! + delta;
            if (e.endPoint != null) e.endPoint = e.endPoint! + delta;
            if (e.points != null) {
              e.points = e.points!.map((p) => p + delta).toList();
            }
          }
          _dragStart = localPos;
        });
        return;
      }
      // Marquee selection
      if (_marqueeStart != null) {
        setState(() {
          _marqueeCurrent = localPos;
        });
      }
      return;
    }

    if (_currentTool == WhiteboardTool.freehand && _freehandPoints != null) {
      final last = _freehandPoints!.last;
      if ((localPos - last).distance > 2.0) {
        _freehandPoints!.add(localPos);
      }
    }

    setState(() { _drawingCurrent = localPos; });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _isZooming = false;
    if (_isPanning) {
      _isPanning = false;
      _dragCanvasStart = null;
      return;
    }

    if (_currentTool == WhiteboardTool.selection) {
      if (_isResizing) {
        setState(() {
          _isResizing = false;
          _resizeHandleIndex = -1;
          _originalRect = null;
          _originalStartPoint = null;
          _originalEndPoint = null;
          _originalPoints = null;
          _resizeDragStart = null;
          _draggingElementId = null;
          _dragStart = null;
        });
      } else if (_draggingElementId != null) {
        setState(() { _draggingElementId = null; _dragStart = null; });
      } else if (_marqueeStart != null && _marqueeCurrent != null) {
        _finalizeMarqueeSelection();
      }
      return;
    }

    // Handle freehand finish
    if (_currentTool == WhiteboardTool.freehand && _freehandPoints != null) {
      if (_freehandPoints!.length >= 2) {
        _saveState();
        final bounds = _computeBounds(_freehandPoints!);
        final element = WhiteboardElement(
          id: _nextId(),
          type: WhiteboardTool.freehand,
          rect: bounds,
          strokeColor: _strokeColor,
          fillColor: Colors.transparent,
          strokeWidth: _strokeWidth,
          points: List.from(_freehandPoints!),
        );
        setState(() {
          _elements.add(element);
          _selectedIds = {element.id};
          _drawingStart = null;
          _drawingCurrent = null;
          _freehandPoints = null;
        });
      } else {
        setState(() {
          _drawingStart = null;
          _drawingCurrent = null;
          _freehandPoints = null;
        });
      }
      return;
    }

    if (_drawingStart != null && _drawingCurrent != null) {
      _saveState();
      final rect = Rect.fromPoints(_drawingStart!, _drawingCurrent!);
      final wasTextTool = _currentTool == WhiteboardTool.text;

      if ((rect.width < 5 || rect.height < 5) && !wasTextTool) {
        setState(() {
          _drawingStart = null;
          _drawingCurrent = null;
          _currentTool = WhiteboardTool.selection; // Revert to selection tool!
        });
        return;
      }

      Rect finalRect = rect;
      if (wasTextTool && (rect.width < 20 || rect.height < 20)) {
        finalRect = Rect.fromLTWH(rect.left, rect.top, 200, 60);
      }

      final effectiveType = wasTextTool
          ? WhiteboardTool.text
          : _currentTool == WhiteboardTool.arrow
              ? WhiteboardTool.arrow
              : _currentTool == WhiteboardTool.line
                  ? WhiteboardTool.line
                  : _currentTool;

      // Auto-attach arrow to nearest shape edge
      Offset? snappedStart;
      Offset? snappedEnd;
      if (effectiveType == WhiteboardTool.arrow) {
        snappedStart = _nearestShapeEdge(_drawingStart!);
        snappedEnd = _nearestShapeEdge(_drawingCurrent!);
      }
      final element = WhiteboardElement(
        id: _nextId(),
        type: effectiveType,
        rect: finalRect,
        strokeColor: _strokeColor,
        fillColor: wasTextTool ? Colors.transparent : _fillColor,
        strokeWidth: _strokeWidth,
        startPoint: snappedStart ?? _drawingStart,
        endPoint: snappedEnd ?? _drawingCurrent,
      );

      setState(() {
        _elements.add(element);
        _selectedIds = {element.id};
        _drawingStart = null;
        _drawingCurrent = null;
        _currentTool = WhiteboardTool.selection; // Revert to Selection tool
      });

      if (wasTextTool) {
        _startTextEditing(rect.center);
      }
    }
  }

  void _finalizeMarqueeSelection() {
    if (_marqueeStart == null || _marqueeCurrent == null) return;
    final marqueeRect = Rect.fromPoints(_marqueeStart!, _marqueeCurrent!);
    final normalizedRect = Rect.fromLTRB(
      min(marqueeRect.left, marqueeRect.right),
      min(marqueeRect.top, marqueeRect.bottom),
      max(marqueeRect.left, marqueeRect.right),
      max(marqueeRect.top, marqueeRect.bottom),
    );
    setState(() {
      _selectedIds = _elements
          .where((e) => normalizedRect.overlaps(e.rect) || normalizedRect.contains(e.rect.center))
          .map((e) => e.id)
          .toSet();
      _marqueeStart = null;
      _marqueeCurrent = null;
    });
  }

  // ── Resize helpers ──
  int _handleAt(Offset point, Rect rect) {
    const handleSize = 8.0;
    // Keep a consistent visual grab area on screen (e.g. 24 screen pixels wide)
    final grabArea = (handleSize + 16.0) / _scale;
    
    final handles = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
      rect.centerLeft,
      rect.centerRight,
      rect.topCenter,
      rect.bottomCenter,
    ];
    for (int i = 0; i < handles.length; i++) {
      final hRect = Rect.fromCenter(
          center: handles[i],
          width: grabArea,
          height: grabArea);
      if (hRect.contains(point)) return i;
    }
    return -1;
  }

  Rect _computeResizedRect(Rect original, int handleIndex, Offset delta,
      {double? aspectRatio}) {
    double l = original.left, t = original.top;
    double r = original.right, b = original.bottom;

    if (aspectRatio != null && (handleIndex >= 0 && handleIndex <= 3)) {
      // Corner handles — maintain aspect ratio
      final isTop = handleIndex == 0 || handleIndex == 1;
      final isLeft = handleIndex == 0 || handleIndex == 2;
      if (isLeft && isTop) {
        l += delta.dx;
        t = b - (r - l) / aspectRatio;
      } else if (!isLeft && isTop) {
        r += delta.dx;
        t = b - (r - l) / aspectRatio;
      } else if (isLeft && !isTop) {
        l += delta.dx;
        b = t + (r - l) / aspectRatio;
      } else {
        r += delta.dx;
        b = t + (r - l) / aspectRatio;
      }
    } else {
      switch (handleIndex) {
        case 0: l += delta.dx; t += delta.dy; break;
        case 1: r += delta.dx; t += delta.dy; break;
        case 2: l += delta.dx; b += delta.dy; break;
        case 3: r += delta.dx; b += delta.dy; break;
        case 4: l += delta.dx;                 break;
        case 5: r += delta.dx;                 break;
        case 6: t += delta.dy;                 break;
        case 7: b += delta.dy;                 break;
      }
    }

    // Enforce minimum size
    const minSize = 10.0;
    if (r - l < minSize) {
      if (handleIndex == 0 || handleIndex == 2 || handleIndex == 4) l = r - minSize;
      else r = l + minSize;
    }
    if (b - t < minSize) {
      if (handleIndex == 0 || handleIndex == 1 || handleIndex == 6) t = b - minSize;
      else b = t + minSize;
    }

    return Rect.fromLTRB(l, t, r, b);
  }

  Offset _scalePoint(Offset point, Rect oldRect, Rect newRect) {
    final oldW = oldRect.width > 0 ? oldRect.width : 1;
    final oldH = oldRect.height > 0 ? oldRect.height : 1;
    final nx = (point.dx - oldRect.left) / oldW;
    final ny = (point.dy - oldRect.top) / oldH;
    return Offset(
      newRect.left + nx * newRect.width,
      newRect.top + ny * newRect.height,
    );
  }

  Rect _computeBounds(List<Offset> pts) {
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final p in pts) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void _onDoubleTap() {
    if (_currentTool != WhiteboardTool.selection) return;
    final localPos = _screenToCanvas(_lastTapPosition);
    final hit = _elementAt(localPos);
    if (hit != null &&
        hit.type != WhiteboardTool.arrow &&
        hit.type != WhiteboardTool.line &&
        hit.type != WhiteboardTool.freehand) {
      _editTextOnElement(hit);
    }
  }

  // ── Text editing ──
  void _startTextEditing(Offset position) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TextInputDialog(
        initialText: '',
        onDone: (text) {
          if (text.isNotEmpty) {
            _saveState();
            setState(() {
              if (_elements.isNotEmpty) {
                final lastEl = _elements.last;
                lastEl.text = text;
                _adjustTextElementHeight(lastEl);
              }
            });
          } else {
            setState(() { if (_elements.isNotEmpty) _elements.removeLast(); });
          }
        },
      ),
    );
  }

  void _editTextOnElement(WhiteboardElement element) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TextInputDialog(
        initialText: element.text ?? '',
        onDone: (text) {
          _saveState();
          setState(() {
            element.text = text;
            _adjustTextElementHeight(element);
          });
        },
      ),
    );
  }

  void _deleteSelected() {
    if (_selectedIds.isEmpty) return;
    _saveState();
    setState(() {
      for (final id in _selectedIds) {
        _loadedImages.remove(id)?.dispose();
      }
      _elements.removeWhere((e) => _selectedIds.contains(e.id));
      _selectedIds = {};
    });
  }

  // ── Duplicate Selected ──
  void _duplicateSelected() {
    if (_selectedIds.isEmpty) return;
    _saveState();
    setState(() {
      final newIds = <String>{};
      final newElements = <WhiteboardElement>[];
      for (final id in _selectedIds) {
        final idx = _elements.indexWhere((e) => e.id == id);
        if (idx >= 0) {
          final original = _elements[idx];
          final newId = _nextId();
          final duplicate = WhiteboardElement(
            id: newId,
            type: original.type,
            rect: original.rect.shift(const Offset(20, 20)),
            strokeColor: original.strokeColor,
            fillColor: original.fillColor,
            strokeWidth: original.strokeWidth,
            text: original.text,
            startPoint: original.startPoint != null
                ? original.startPoint! + const Offset(20, 20)
                : null,
            endPoint: original.endPoint != null
                ? original.endPoint! + const Offset(20, 20)
                : null,
            points: original.points?.map((p) => p + const Offset(20, 20)).toList(),
            imageBytes: original.imageBytes,
            imageName: original.imageName,
            rotation: original.rotation,
            cornerRadius: original.cornerRadius,
          );
          newElements.add(duplicate);
          newIds.add(newId);
          if (original.imageBytes != null && _loadedImages.containsKey(id)) {
            _loadedImages[newId] = _loadedImages[id]!;
          }
        }
      }
      _elements.addAll(newElements);
      _selectedIds = newIds;
    });
  }

  // ── Layer Ordering ──
  void _bringForward() {
    if (_selectedIds.isEmpty) return;
    _saveState();
    setState(() {
      for (final id in _selectedIds.toList()) {
        final idx = _elements.indexWhere((e) => e.id == id);
        if (idx >= 0 && idx < _elements.length - 1) {
          final temp = _elements[idx];
          _elements[idx] = _elements[idx + 1];
          _elements[idx + 1] = temp;
        }
      }
    });
  }

  void _sendBackward() {
    if (_selectedIds.isEmpty) return;
    _saveState();
    setState(() {
      for (final id in _selectedIds.toList()) {
        final idx = _elements.indexWhere((e) => e.id == id);
        if (idx > 0) {
          final temp = _elements[idx];
          _elements[idx] = _elements[idx - 1];
          _elements[idx - 1] = temp;
        }
      }
    });
  }

  void _bringToFront() {
    if (_selectedIds.isEmpty) return;
    _saveState();
    setState(() {
      final moved = <WhiteboardElement>[];
      for (final id in _selectedIds.toList()) {
        final idx = _elements.indexWhere((e) => e.id == id);
        if (idx >= 0) {
          moved.add(_elements.removeAt(idx));
        }
      }
      _elements.addAll(moved);
    });
  }

  void _sendToBack() {
    if (_selectedIds.isEmpty) return;
    _saveState();
    setState(() {
      final moved = <WhiteboardElement>[];
      for (final id in _selectedIds.toList()) {
        final idx = _elements.indexWhere((e) => e.id == id);
        if (idx >= 0) {
          moved.add(_elements.removeAt(idx));
        }
      }
      _elements.insertAll(0, moved);
    });
  }

  // ── Snap to Grid ──
  Offset _snapToGridValue(Offset pt) {
    if (!_snapToGrid) return pt;
    const gridSize = 25.0;
    return Offset(
      (pt.dx / gridSize).round() * gridSize,
      (pt.dy / gridSize).round() * gridSize,
    );
  }

  
  // ── Insert Image ──
  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes ??
          (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null) return;

      // Decode image at reduced resolution for performance
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 1200,
        targetHeight: 1200,
      );
      final frame = await codec.getNextFrame();
      final img = frame.image;
      codec.dispose();
      final imgW = img.width.toDouble();
      final imgH = img.height.toDouble();

      // Place at canvas center with reasonable default size
      const maxDim = 400.0;
      final scale = imgW > imgH
          ? min(maxDim, imgW) / imgW
          : min(maxDim, imgH) / imgH;
      final w = imgW * scale;
      final h = imgH * scale;
      final center = _screenToCanvas(const Offset(400, 300));
      final rect = Rect.fromCenter(
          center: center,
          width: w.clamp(50, maxDim),
          height: h.clamp(50, maxDim));

      final elementId = _nextId();
      _loadedImages[elementId] = img;

      _saveState();
      setState(() {
        _elements.add(WhiteboardElement(
          id: elementId,
          type: WhiteboardTool.rectangle,
          rect: rect,
          strokeColor: Colors.transparent,
          fillColor: Colors.transparent,
          imageBytes: bytes,
          imageName: file.name,
        ));
        _selectedIds = {elementId};
        _currentTool = WhiteboardTool.selection;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load image: $e')),
        );
      }
    }
  }

  // ── Export PDF ──
  Future<void> _exportPdf() async {
    if (_elements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to export.')),
      );
      return;
    }
    try {
      final bytes = await _generateExportBytes(true);
      if (bytes == null) return;
      final result = await FilePicker.saveFile(
        dialogTitle: 'Save Whiteboard as PDF',
        fileName: 'whiteboard.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null) return;
      await File(result).writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to ${result.split('\\').last.split('/').last}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export PDF: $e')),
        );
      }
    }
  }

  // ── Add Sticky Note ──
  void _addStickyNote() {
    final center = _screenToCanvas(const Offset(400, 300));
    final noteId = _nextId();
    _saveState();
    setState(() {
      _elements.add(WhiteboardElement(
        id: noteId,
        type: WhiteboardTool.rectangle,
        rect: Rect.fromCenter(center: center, width: 200, height: 160),
        strokeColor: const Color(0xFFE67700),
        fillColor: const Color(0xFFFFF3CD),
        strokeWidth: 1.5,
        text: 'Double-click to edit',
      ));
      _selectedIds = {noteId};
      _currentTool = WhiteboardTool.selection;
    });
  }

  // ── Arrow auto-attachment: find nearest shape edge point ──
  Offset? _nearestShapeEdge(Offset point, {String? excludeId}) {
    double bestDist = 30.0 / _scale;
    Offset? bestPoint;
    for (final el in _elements) {
      if (excludeId != null && el.id == excludeId) continue;
      if (el.type == WhiteboardTool.arrow || el.type == WhiteboardTool.line || el.type == WhiteboardTool.freehand) continue;
      final rect = el.rect;
      final edges = <Offset>[
        _closestPointOnSegment(point, rect.topLeft, rect.topRight),
        _closestPointOnSegment(point, rect.topRight, rect.bottomRight),
        _closestPointOnSegment(point, rect.bottomRight, rect.bottomLeft),
        _closestPointOnSegment(point, rect.bottomLeft, rect.topLeft),
      ];
      for (final edgePt in edges) {
        final dist = (point - edgePt).distance;
        if (dist < bestDist) {
          bestDist = dist;
          bestPoint = edgePt;
        }
      }
      final centerDist = (point - rect.center).distance;
      if (centerDist < bestDist) {
        bestDist = centerDist;
        bestPoint = rect.center;
      }
    }
    return bestPoint;
  }

  Offset _closestPointOnSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final ab2 = max(ab.dx * ab.dx + ab.dy * ab.dy, 0.001);
    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / ab2;
    return a + ab * t.clamp(0.0, 1.0);
  }

  // ── Export PNG ──
  Future<Uint8List?> _generateExportBytes(bool isHorizontal) async {
    if (_elements.isEmpty) return null;

    try {
      // Compute bounding box of all elements
      double minX = double.infinity, minY = double.infinity;
      double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

      for (final el in _elements) {
        if (el.rect.left < minX) minX = el.rect.left;
        if (el.rect.top < minY) minY = el.rect.top;
        if (el.rect.right > maxX) maxX = el.rect.right;
        if (el.rect.bottom > maxY) maxY = el.rect.bottom;
        if (el.startPoint != null) {
          if (el.startPoint!.dx < minX) minX = el.startPoint!.dx;
          if (el.startPoint!.dy < minY) minY = el.startPoint!.dy;
          if (el.startPoint!.dx > maxX) maxX = el.startPoint!.dx;
          if (el.startPoint!.dy > maxY) maxY = el.startPoint!.dy;
        }
        if (el.endPoint != null) {
          if (el.endPoint!.dx < minX) minX = el.endPoint!.dx;
          if (el.endPoint!.dy < minY) minY = el.endPoint!.dy;
          if (el.endPoint!.dx > maxX) maxX = el.endPoint!.dx;
          if (el.endPoint!.dy > maxY) maxY = el.endPoint!.dy;
        }
        if (el.points != null) {
          for (final p in el.points!) {
            if (p.dx < minX) minX = p.dx;
            if (p.dy < minY) minY = p.dy;
            if (p.dx > maxX) maxX = p.dx;
            if (p.dy > maxY) maxY = p.dy;
          }
        }
      }

      if (minX == double.infinity || maxX == double.negativeInfinity ||
          minY == double.infinity || maxY == double.negativeInfinity) {
        minX = 0;
        minY = 0;
        maxX = 800;
        maxY = 600;
      }

      final double contentW = maxX - minX;
      final double contentH = maxY - minY;

      // Aspect ratio R
      final double R = isHorizontal ? 1.6 : 0.625;
      const double pad = 40.0;
      final double requiredW = contentW + pad * 2;
      final double requiredH = contentH + pad * 2;

      double canvasW = requiredW;
      double canvasH = requiredH;
      if (canvasW / canvasH > R) {
        canvasH = canvasW / R;
      } else {
        canvasW = canvasH * R;
      }

      // High-res output dimensions
      final double outputW = isHorizontal ? 1920.0 : 1200.0;
      final double outputH = isHorizontal ? 1200.0 : 1920.0;
      final double scale = outputW / canvasW;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, outputW, outputH));

      // White background
      canvas.drawRect(
        Rect.fromLTWH(0, 0, outputW, outputH),
        Paint()..color = Colors.white,
      );

      // Save canvas state, scale, and draw grid in scaled coordinate space
      canvas.save();
      canvas.scale(scale);

      final gridPaint = Paint()
        ..color = const Color(0xFFEFEFEF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      const gridS = 30.0;
      for (double x = 0; x <= canvasW; x += gridS) {
        canvas.drawLine(Offset(x, 0), Offset(x, canvasH), gridPaint);
      }
      for (double y = 0; y <= canvasH; y += gridS) {
        canvas.drawLine(Offset(0, y), Offset(canvasW, y), gridPaint);
      }

      // Translate to center content
      canvas.save();
      final double shiftX = (canvasW - contentW) / 2 - minX;
      final double shiftY = (canvasH - contentH) / 2 - minY;
      canvas.translate(shiftX, shiftY);

      for (final element in _elements) {
        canvas.save();
        if (element.rotation != 0) {
          final center = element.rect.center;
          canvas.translate(center.dx, center.dy);
          canvas.rotate(element.rotation);
          canvas.translate(-center.dx, -center.dy);
        }

        final exportPainter = WhiteboardPainter(
          elements: [element],
          currentTool: WhiteboardTool.selection,
          strokeColor: element.strokeColor,
          fillColor: element.fillColor,
          strokeWidth: element.strokeWidth,
          loadedImages: _loadedImages,
        );
        exportPainter._drawElement(canvas, element);
        canvas.restore();
      }
      
      canvas.restore(); // Undo translate
      canvas.restore(); // Undo scale

      final picture = recorder.endRecording();
      final image = await picture.toImage(outputW.toInt(), outputH.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Failed to generate export bytes: $e");
      return null;
    }
  }

  void _showExportDialog() {
    if (_elements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to export. Draw something on the whiteboard first!')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: WhiteboardExportDialog(
                onGenerate: _generateExportBytes,
                onCancel: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Save & Load Whiteboards Logic ──

  String _formatDateTime(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _saveBoard({String? overrideName}) async {
    final name = overrideName ?? _currentWhiteboardName;
    
    // Generate a unique ID if not present
    final String boardId = _currentWhiteboardId ?? "wb_${DateTime.now().millisecondsSinceEpoch}";
    final String nowStr = DateTime.now().toIso8601String();

    try {
      // 1. Serialize elements to JSON string
      final elementsList = _elements.map((e) => e.toMap()).toList();
      final elementsJson = jsonEncode(elementsList);

      // 2. Save individual board data
      await StorageService.setString("whiteboard_data_$boardId", elementsJson);

      // 3. Update boards list metadata
      final listJson = StorageService.getString("whiteboard_list") ?? "[]";
      final List<dynamic> listDecoded = jsonDecode(listJson);
      final List<Map<String, dynamic>> boards = List<Map<String, dynamic>>.from(listDecoded);

      final index = boards.indexWhere((b) => b['id'] == boardId);
      if (index >= 0) {
        boards[index]['name'] = name;
        boards[index]['updatedAt'] = nowStr;
      } else {
        boards.add({
          'id': boardId,
          'name': name,
          'createdAt': nowStr,
          'updatedAt': nowStr,
        });
      }

      await StorageService.setString("whiteboard_list", jsonEncode(boards));

      setState(() {
        _currentWhiteboardId = boardId;
        _currentWhiteboardName = name;
        _currentWhiteboardUpdatedAt = nowStr;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Whiteboard '$name' saved successfully."),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save whiteboard: $e"),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadBoard(String boardId) async {
    try {
      // 1. Get board data
      final boardJson = StorageService.getString("whiteboard_data_$boardId");
      if (boardJson == null) {
        throw Exception("Board data not found.");
      }

      // 2. Get board metadata to fetch name & updatedAt
      final listJson = StorageService.getString("whiteboard_list") ?? "[]";
      final List<dynamic> listDecoded = jsonDecode(listJson);
      final meta = listDecoded.firstWhere((b) => b['id'] == boardId, orElse: () => null);
      if (meta == null) {
        throw Exception("Board metadata not found.");
      }

      // 3. Deserialize elements
      final List<dynamic> elementsList = jsonDecode(boardJson);
      final loadedElements = elementsList.map((m) => WhiteboardElement.fromMap(m as Map<String, dynamic>)).toList();

      // 4. Dispose current images and set new elements
      for (final img in _loadedImages.values) {
        img.dispose();
      }
      _loadedImages.clear();

      setState(() {
        _elements.clear();
        _elements.addAll(loadedElements);
        _currentWhiteboardId = boardId;
        _currentWhiteboardName = meta['name'] as String;
        _currentWhiteboardUpdatedAt = meta['updatedAt'] as String;
        _selectedIds.clear();
        _undoStack.clear();
        _redoStack.clear();
      });

      // 5. Preload images if any elements contain image bytes
      for (final el in loadedElements) {
        if (el.imageBytes != null) {
          final codec = await ui.instantiateImageCodec(el.imageBytes!);
          final frame = await codec.getNextFrame();
          _loadedImages[el.id] = frame.image;
        }
      }
      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Whiteboard '${meta['name']}' loaded successfully."),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to load whiteboard: $e"),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteBoard(String boardId) async {
    try {
      // 1. Remove board data and update list
      await StorageService.remove("whiteboard_data_$boardId");

      final listJson = StorageService.getString("whiteboard_list") ?? "[]";
      final List<dynamic> listDecoded = jsonDecode(listJson);
      final List<Map<String, dynamic>> boards = List<Map<String, dynamic>>.from(listDecoded);

      boards.removeWhere((b) => b['id'] == boardId);
      await StorageService.setString("whiteboard_list", jsonEncode(boards));

      // 2. If it was active, reset active board state
      if (_currentWhiteboardId == boardId) {
        setState(() {
          _currentWhiteboardId = null;
          _currentWhiteboardName = "Untitled Whiteboard";
          _currentWhiteboardUpdatedAt = "";
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Whiteboard deleted successfully."),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to delete whiteboard: $e"),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _renameCurrentWhiteboardDialog() {
    final controller = TextEditingController(text: _currentWhiteboardName);
    final tokens = FocusOsTheme.of(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: tokens.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: tokens.borderSubtle),
          ),
          title: Text(
            'Rename Whiteboard',
            style: TextStyle(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: tokens.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter whiteboard name',
              hintStyle: TextStyle(color: tokens.textMuted),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: tokens.borderSubtle)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: tokens.accent)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: tokens.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  Navigator.of(context).pop();
                  if (_currentWhiteboardId != null) {
                    _saveBoard(overrideName: newName);
                  } else {
                    setState(() {
                      _currentWhiteboardName = newName;
                    });
                  }
                }
              },
              child: Text('Rename', style: TextStyle(color: tokens.accent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _promptSaveDialog() {
    final controller = TextEditingController(text: _currentWhiteboardName == "Untitled Whiteboard" ? "" : _currentWhiteboardName);
    final tokens = FocusOsTheme.of(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: tokens.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: tokens.borderSubtle),
          ),
          title: Text(
            'Save Whiteboard',
            style: TextStyle(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: tokens.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. System Design Architecture',
              hintStyle: TextStyle(color: tokens.textMuted),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: tokens.borderSubtle)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: tokens.accent)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: tokens.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  Navigator.of(context).pop();
                  _saveBoard(overrideName: newName);
                }
              },
              child: Text('Save', style: TextStyle(color: tokens.accent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showSavedBoardsList() {
    final tokens = FocusOsTheme.of(context);
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final listJson = StorageService.getString("whiteboard_list") ?? "[]";
            final List<dynamic> decoded = jsonDecode(listJson);
            final List<Map<String, dynamic>> boards = List<Map<String, dynamic>>.from(decoded);

            return AlertDialog(
              backgroundColor: tokens.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: tokens.borderSubtle),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Saved Whiteboards',
                    style: TextStyle(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_rounded, color: tokens.accent),
                    tooltip: 'New Whiteboard',
                    onPressed: () {
                      Navigator.of(context).pop();
                      _startNewBoard();
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                height: 300,
                child: boards.isEmpty
                    ? Center(
                        child: Text(
                          'No saved boards yet.\nDraw something and click save!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: tokens.textMuted, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        itemCount: boards.length,
                        itemBuilder: (context, index) {
                          final board = boards[index];
                          final id = board['id'] as String;
                          final name = board['name'] as String;
                          final isCurrent = _currentWhiteboardId == id;
                          final updatedAtStr = board['updatedAt'] != null
                              ? _formatDateTime(DateTime.parse(board['updatedAt'] as String))
                              : 'Unknown';

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: isCurrent ? tokens.accent.withValues(alpha: 0.05) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isCurrent ? tokens.accent.withValues(alpha: 0.3) : tokens.borderSubtle.withValues(alpha: 0.5),
                              ),
                            ),
                            child: ListTile(
                              title: Text(
                                name,
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                'Last modified: $updatedAtStr',
                                style: TextStyle(color: tokens.textMuted, fontSize: 11),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.folder_open_rounded, color: tokens.accent, size: 20),
                                    tooltip: 'Load Board',
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      _loadBoard(id);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                    tooltip: 'Delete Board',
                                    onPressed: () {
                                      _deleteBoard(id).then((_) {
                                        setDialogState(() {});
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close', style: TextStyle(color: tokens.textSecondary)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _startNewBoard() {
    if (_elements.isEmpty) {
      setState(() {
        _currentWhiteboardId = null;
        _currentWhiteboardName = "Untitled Whiteboard";
        _currentWhiteboardUpdatedAt = "";
      });
      return;
    }

    final tokens = FocusOsTheme.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: tokens.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: tokens.borderSubtle),
          ),
          title: Text(
            'New Whiteboard',
            style: TextStyle(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to start a new whiteboard? Any unsaved changes on the current canvas will be lost.',
            style: TextStyle(color: tokens.textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: tokens.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                for (final img in _loadedImages.values) {
                  img.dispose();
                }
                _loadedImages.clear();
                setState(() {
                  _elements.clear();
                  _currentWhiteboardId = null;
                  _currentWhiteboardName = "Untitled Whiteboard";
                  _currentWhiteboardUpdatedAt = "";
                  _selectedIds.clear();
                  _undoStack.clear();
                  _redoStack.clear();
                });
              },
              child: const Text('Start New', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _clearAll() {
    if (_elements.isEmpty) return;
    _saveState();
    setState(() {
      for (final img in _loadedImages.values) {
        img.dispose();
      }
      _loadedImages.clear();
      _elements.clear();
      _selectedIds = {};
    });
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return motion.PremiumEnterTransition(
      duration: motion.PremiumDurations.pageTransition,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: tokens.textPrimary),
                  onPressed: widget.onBack,
                  splashRadius: 20,
                  tooltip: 'Back to Tools',
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _currentWhiteboardName,
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                              letterSpacing: -0.5),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.edit_outlined, size: 16, color: tokens.textMuted),
                          onPressed: _renameCurrentWhiteboardDialog,
                          splashRadius: 16,
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          tooltip: 'Rename Whiteboard',
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                        _currentWhiteboardId == null
                            ? 'Unsaved local board — Sketch diagrams, draw shapes, and write notes'
                            : 'Saved board — Last updated ${_formatDateTime(DateTime.parse(_currentWhiteboardUpdatedAt))}',
                        style: TextStyle(fontSize: 13, color: tokens.textMuted)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildToolbar(tokens),
            const SizedBox(height: 12),
            // Canvas
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tokens.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Focus(
                    autofocus: true,
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        final tool = _keyToolMap[event.logicalKey];
                        if (tool != null) {
                          setState(() {
                            _currentTool = tool;
                            if (tool == WhiteboardTool.hand) {
                              _selectedIds = {};
                            }
                            if ([
                              WhiteboardTool.rectangle,
                              WhiteboardTool.diamond,
                              WhiteboardTool.ellipse,
                              WhiteboardTool.arrow,
                              WhiteboardTool.line,
                              WhiteboardTool.triangle,
                              WhiteboardTool.cloud,
                              WhiteboardTool.star,
                            ].contains(tool)) {
                              _lastActiveShape = tool;
                            }
                          });
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.delete ||
                            event.logicalKey == LogicalKeyboardKey.backspace) {
                          _deleteSelected();
                          return KeyEventResult.handled;
                        }
                        final isCtrlOrCmd = HardwareKeyboard
                                .instance
                                .isLogicalKeyPressed(
                                    LogicalKeyboardKey.controlLeft) ||
                            HardwareKeyboard.instance.isLogicalKeyPressed(
                                LogicalKeyboardKey.controlRight) ||
                            HardwareKeyboard.instance.isLogicalKeyPressed(
                                LogicalKeyboardKey.metaLeft) ||
                            HardwareKeyboard.instance.isLogicalKeyPressed(
                                LogicalKeyboardKey.metaRight);
                        final isShift = HardwareKeyboard
                                .instance
                                .isLogicalKeyPressed(
                                    LogicalKeyboardKey.shiftLeft) ||
                            HardwareKeyboard.instance.isLogicalKeyPressed(
                                LogicalKeyboardKey.shiftRight);
                        if (isCtrlOrCmd &&
                            !isShift &&
                            event.logicalKey == LogicalKeyboardKey.keyZ) {
                          _undo();
                          return KeyEventResult.handled;
                        }
                        if (isCtrlOrCmd &&
                            isShift &&
                            event.logicalKey == LogicalKeyboardKey.keyZ) {
                          _redo();
                          return KeyEventResult.handled;
                        }
                        if (isCtrlOrCmd &&
                            event.logicalKey == LogicalKeyboardKey.keyD) {
                          _duplicateSelected();
                          return KeyEventResult.handled;
                        }
                        if (isCtrlOrCmd &&
                            event.logicalKey == LogicalKeyboardKey.keyE) {
                          _showExportDialog();
                          return KeyEventResult.handled;
                        }
                        if (isCtrlOrCmd &&
                            event.logicalKey == LogicalKeyboardKey.keyI) {
                          _pickImage();
                          return KeyEventResult.handled;
                        }
                        if (isCtrlOrCmd &&
                            event.logicalKey == LogicalKeyboardKey.keyA) {
                          setState(() => _selectedIds =
                              _elements.map((e) => e.id).toSet());
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.escape) {
                          setState(() => _selectedIds = {});
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) {
                        _activePointerCount++;
                      },
                      onPointerUp: (event) {
                        _activePointerCount = max(0, _activePointerCount - 1);
                      },
                      onPointerCancel: (event) {
                        _activePointerCount = max(0, _activePointerCount - 1);
                      },
                      onPointerSignal: (event) {
                        if (event is PointerScrollEvent) {
                          setState(() {
                            final oldScale = _scale;
                            _scale =
                                (_scale - event.scrollDelta.dy * 0.001)
                                    .clamp(0.3, 3.0);
                            final cursor = event.localPosition;
                            _panOffset = Offset(
                              cursor.dx -
                                  (cursor.dx - _panOffset.dx) *
                                      (_scale / oldScale),
                              cursor.dy -
                                  (cursor.dy - _panOffset.dy) *
                                      (_scale / oldScale),
                            );
                          });
                        }
                      },
                      child: MouseRegion(
                        cursor: _currentTool == WhiteboardTool.hand
                            ? (_isPanning ? SystemMouseCursors.grabbing : SystemMouseCursors.grab)
                            : SystemMouseCursors.basic,
                        child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) =>
                            _lastTapPosition = details.localPosition,
                        onTapUp: (details) {
                          if (_currentTool == WhiteboardTool.selection) {
                            final localPos = _screenToCanvas(details.localPosition);
                            final hit = _elementAt(localPos);
                            final isShift = HardwareKeyboard.instance.isShiftPressed;
                            setState(() {
                              if (hit != null) {
                                if (isShift) {
                                  if (_selectedIds.contains(hit.id)) {
                                    _selectedIds = Set.from(_selectedIds)..remove(hit.id);
                                  } else {
                                    _selectedIds = Set.from(_selectedIds)..add(hit.id);
                                  }
                                } else {
                                  _selectedIds = {hit.id};
                                }
                              } else {
                                if (!isShift) {
                                  _selectedIds = {};
                                }
                              }
                            });
                          }
                        },
                        onDoubleTap: _onDoubleTap,
                        onSecondaryTapDown: (details) {
                          if (_currentTool != WhiteboardTool.selection) return;
                          final localPos =
                              _screenToCanvas(details.localPosition);
                          final hit = _elementAt(localPos);
                          if (hit != null) {
                            showMenu(
                              context: context,
                              position: RelativeRect.fromRect(
                                  details.localPosition & const Size(1, 1),
                                  Offset.zero & Size.zero),
                              items: [                                  PopupMenuItem(
                                      child: const Text('Delete'),
                                      onTap: () {
                                        _saveState();
                                        setState(() {
                                          _loadedImages.remove(hit.id)?.dispose();
                                          _elements.remove(hit);
                                          _selectedIds.remove(hit.id);
                                        });
                                      }),
                                if (hit.type != WhiteboardTool.arrow &&
                                    hit.type != WhiteboardTool.line &&
                                    hit.type != WhiteboardTool.freehand)
                                  PopupMenuItem(
                                      child: const Text('Edit Text'),
                                      onTap: () =>
                                          _editTextOnElement(hit)),
                              ],
                            );
                          }
                        },
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        onScaleEnd: _onScaleEnd,
                        child: RepaintBoundary(
                          child: Container(
                          color: Colors.transparent,
                          child: CustomPaint(
                            painter: WhiteboardPainter(
                              elements: _elements,
                              selectedIds: _selectedIds,
                              currentTool: _currentTool,
                              drawingStart: _drawingStart,
                              drawingCurrent: _drawingCurrent,
                              freehandPoints: _freehandPoints,
                              strokeColor: _strokeColor,
                              fillColor: _fillColor,
                              strokeWidth: _strokeWidth,
                              panOffset: _panOffset,
                              scale: _scale,
                              loadedImages: _loadedImages,
                              marqueeRect: _marqueeStart != null && _marqueeCurrent != null
                                  ? Rect.fromPoints(_marqueeStart!, _marqueeCurrent!)
                                  : null,
                            ),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ),
              _buildRightPropertiesPanel(tokens),
            ],
          ),
        ),
      ),
    ),
            const SizedBox(height: 8),
            // Floating history panel
            if (_showHistoryPanel)
              _buildHistoryPanel(tokens),
            // Status bar
            Row(
              children: [
                Text('${_elements.length} element(s)',
                    style: TextStyle(fontSize: 11, color: tokens.textMuted)),
                const Spacer(),
                Text(
                    'Scroll to zoom · Alt+drag to pan · Dbl-click text to edit',
                    style: TextStyle(fontSize: 11, color: tokens.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Toolbar ──
  // ── Build History Panel ──
  Widget _buildHistoryPanel(ThemeTokens tokens) {
    final historyCount = _undoStack.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: 280,
        constraints: const BoxConstraints(maxHeight: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8E8E8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history_rounded, size: 14, color: tokens.textPrimary),
                const SizedBox(width: 6),
                Text('History',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _showHistoryPanel = false),
                  child: Icon(Icons.close_rounded, size: 14, color: tokens.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Undo steps',
                  style: TextStyle(fontSize: 11, color: tokens.textMuted),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$historyCount / 50',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: historyCount > 0 ? const Color(0xFF1971C2) : tokens.textMuted,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: CustomPaint(
                size: const Size(double.infinity, 40),
                painter: _HistoryBarPainter(
                  totalSlots: 50,
                  filledCount: historyCount,
                  maxVisible: 8,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                GestureDetector(
                  onTap: _undoStack.isNotEmpty ? _undo : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _undoStack.isNotEmpty ? const Color(0xFF1971C2) : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.undo_rounded, size: 12,
                          color: _undoStack.isNotEmpty ? Colors.white : const Color(0xFFBBBBBB)),
                        const SizedBox(width: 4),
                        Text('Undo',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _undoStack.isNotEmpty ? Colors.white : const Color(0xFFBBBBBB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _redoStack.isNotEmpty ? _redo : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _redoStack.isNotEmpty ? const Color(0xFF1971C2) : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.redo_rounded, size: 12,
                          color: _redoStack.isNotEmpty ? Colors.white : const Color(0xFFBBBBBB)),
                        const SizedBox(width: 4),
                        Text('Redo',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _redoStack.isNotEmpty ? Colors.white : const Color(0xFFBBBBBB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Build Snap Toggle ──
  Widget _buildSnapToggle() {
    return GestureDetector(
      onTap: () => setState(() => _snapToGrid = !_snapToGrid),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _snapToGrid ? const Color(0xFF1971C2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Tooltip(
          message: _snapToGrid ? 'Snap to Grid: ON' : 'Snap to Grid: OFF',
          child: Icon(
            Icons.grid_on_rounded,
            size: 16,
            color: _snapToGrid ? Colors.white : const Color(0xFF555555),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(ThemeTokens tokens) {
    final mainTools = [
      (WhiteboardTool.selection, Icons.near_me_outlined, 'Selection (V)'),
      (WhiteboardTool.hand, Icons.pan_tool_outlined, 'Hand (H)'),
    ];
    final remainingTools = [
      (WhiteboardTool.freehand, Icons.gesture, 'Freehand (F)'),
      (WhiteboardTool.text, Icons.text_fields_rounded, 'Text (T)'),
    ];

    final shapesController = MenuController();

    Widget _shapeMenuItem(WhiteboardTool tool, IconData icon, String tooltip) {
      final active = _currentTool == tool;
      return GestureDetector(
        onTap: () {
          setState(() {
            _currentTool = tool;
            _lastActiveShape = tool;
          });
          shapesController.close();
        },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1971C2) : const Color(0xFFF3F3F3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? const Color(0xFF1971C2) : const Color(0xFFE8E8E8),
            ),
          ),
          child: Tooltip(
            message: tooltip,
            child: Icon(
              icon,
              size: 18,
              color: active ? Colors.white : const Color(0xFF555555),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...mainTools.map((t) => _toolButton(t.$1, t.$2, t.$3)),
            const SizedBox(width: 2),
            // Shapes Dropdown
            MenuAnchor(
              controller: shapesController,
              builder: (context, controller, child) {
                final isShapeActive = [
                  WhiteboardTool.rectangle,
                  WhiteboardTool.diamond,
                  WhiteboardTool.ellipse,
                  WhiteboardTool.arrow,
                  WhiteboardTool.line,
                  WhiteboardTool.triangle,
                  WhiteboardTool.cloud,
                  WhiteboardTool.star,
                ].contains(_currentTool);

                final activeShape = isShapeActive ? _currentTool : _lastActiveShape;
                final shapeIcon = _getShapeIcon(activeShape);

                return MouseRegion(
                  onEnter: (_) {
                    if (!controller.isOpen) {
                      controller.open();
                    }
                  },
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentTool = activeShape;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      height: 32,
                      decoration: BoxDecoration(
                        color: isShapeActive ? const Color(0xFF1971C2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            shapeIcon,
                            size: 18,
                            color: isShapeActive ? Colors.white : const Color(0xFF555555),
                          ),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 14,
                            color: isShapeActive ? Colors.white70 : const Color(0xFF888888),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              menuChildren: [
                Container(
                  width: 200,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Shapes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF888888),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _shapeMenuItem(WhiteboardTool.rectangle, Icons.crop_square_rounded, 'Rectangle (R)'),
                          _shapeMenuItem(WhiteboardTool.diamond, Icons.diamond_outlined, 'Diamond (D)'),
                          _shapeMenuItem(WhiteboardTool.ellipse, Icons.circle_outlined, 'Ellipse (E)'),
                          _shapeMenuItem(WhiteboardTool.arrow, Icons.arrow_forward_rounded, 'Arrow (A)'),
                          _shapeMenuItem(WhiteboardTool.line, Icons.show_chart_rounded, 'Line (L)'),
                          _shapeMenuItem(WhiteboardTool.triangle, Icons.change_history, 'Triangle (G)'),
                          _shapeMenuItem(WhiteboardTool.cloud, Icons.cloud_queue, 'Cloud (C)'),
                          _shapeMenuItem(WhiteboardTool.star, Icons.star_border, 'Star (S)'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 2),
            ...remainingTools.map((t) => _toolButton(t.$1, t.$2, t.$3)),
            const SizedBox(width: 8),
            Container(
                width: 1, height: 24, color: const Color(0xFFE8E8E8)),
            const SizedBox(width: 8),
            // Stroke color
            MenuAnchor(
              builder: (context, controller, child) {
                return _colorCircle(
                  color: _strokeColor,
                  onTap: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                );
              },
              menuChildren: [
                _HslColorPicker(
                  currentColor: _strokeColor,
                  onColorChanged: (color) {
                    setState(() {
                      _strokeColor = color;
                    });
                    _updateSelectedStrokeColor(color);
                  },
                ),
              ],
            ),
            const SizedBox(width: 6),
            // Fill color
            MenuAnchor(
              builder: (context, controller, child) {
                return _colorCircle(
                  color: _fillColor == Colors.transparent
                      ? Colors.transparent
                      : _fillColor,
                  onTap: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                  isFill: true,
                );
              },
              menuChildren: [
                _HslColorPicker(
                  currentColor: _fillColor == Colors.transparent
                      ? const Color(0xFF888888)
                      : _fillColor,
                  includeTransparent: true,
                  onColorChanged: (color) {
                    setState(() {
                      _fillColor = color;
                    });
                    _updateSelectedFillColor(color);
                  },
                ),
              ],
            ),
            const SizedBox(width: 6),
            // Stroke width
            Container(
              width: 80,
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFFF3F3F3),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.line_weight,
                      size: 12, color: const Color(0xFF888888)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 2,
                        activeTrackColor: const Color(0xFF1971C2),
                        inactiveTrackColor: const Color(0xFFDDDDDD),
                        thumbColor: const Color(0xFF1971C2),
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 12),
                      ),
                      child: Slider(
                        value: _strokeWidth,
                        min: 1.0,
                        max: 8.0,
                        onChanged: (v) {
                          setState(() {
                            _strokeWidth = v;
                          });
                          _updateSelectedStrokeWidth(v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Zoom controls
            _zoomButton(Icons.zoom_out_rounded, 'Zoom out', () {
              setState(() => _scale = (_scale - 0.1).clamp(0.3, 3.0));
            }, _scale <= 0.3),
            SizedBox(
              width: 36,
              child: Text('${(_scale * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF555555))),
            ),
            _zoomButton(Icons.zoom_in_rounded, 'Zoom in', () {
              setState(() => _scale = (_scale + 0.1).clamp(0.3, 3.0));
            }, _scale >= 3.0),
            _iconButton(Icons.refresh_rounded, 'Reset zoom', () {
              setState(() {
                _scale = 1.0;
                _panOffset = Offset.zero;
              });
            }, false),
            const SizedBox(width: 4),
            _buildSnapToggle(),
            const SizedBox(width: 4),
            Container(
                width: 1, height: 24, color: const Color(0xFFE8E8E8)),
            const SizedBox(width: 4),
            _iconButton(Icons.undo_rounded, 'Undo', _undo, _undoStack.isEmpty),
            const SizedBox(width: 4),
            _iconButton(Icons.redo_rounded, 'Redo', _redo, _redoStack.isEmpty),
            const SizedBox(width: 2),
            _iconButton(Icons.history_rounded, 'History Panel', () {
              setState(() => _showHistoryPanel = !_showHistoryPanel);
            }, false),
            const SizedBox(width: 4),
            _iconButton(Icons.delete_outline_rounded, 'Delete selected',
                _deleteSelected, _selectedIds.isEmpty),
            const SizedBox(width: 2),
            _iconButton(Icons.layers_outlined, 'Bring Forward', _bringForward, _selectedIds.isEmpty),
            const SizedBox(width: 2),
            _iconButton(Icons.layers_clear_outlined, 'Send Backward', _sendBackward, _selectedIds.isEmpty),
            const SizedBox(width: 2),
            _iconButton(Icons.flip_to_front_rounded, 'Bring to Front', _bringToFront, _selectedIds.isEmpty),
            const SizedBox(width: 2),
            _iconButton(Icons.flip_to_back_rounded, 'Send to Back', _sendToBack, _selectedIds.isEmpty),
            const SizedBox(width: 4),
            const SizedBox(width: 4),
            Container(
                width: 1, height: 24, color: const Color(0xFFE8E8E8)),
            const SizedBox(width: 4),
            _iconButton(Icons.folder_open_outlined, 'Saved Whiteboards', _showSavedBoardsList, false),
            const SizedBox(width: 2),
            _iconButton(Icons.save_outlined, 'Save Whiteboard', () {
              if (_currentWhiteboardId == null) {
                _promptSaveDialog();
              } else {
                _saveBoard();
              }
            }, false),
            const SizedBox(width: 4),
            _iconButton(Icons.add_photo_alternate_outlined, 'Insert Image',
                _pickImage, _isExporting),
            const SizedBox(width: 4),
            _iconButton(Icons.image_outlined, 'Export PNG', _showExportDialog,
                _elements.isEmpty),
            const SizedBox(width: 2),
            _iconButton(Icons.picture_as_pdf_outlined, 'Export PDF', _exportPdf,
                _elements.isEmpty),
            const SizedBox(width: 2),
            _iconButton(Icons.note_add_outlined, 'Add Sticky Note', _addStickyNote,
                false),
            const SizedBox(width: 4),
            _iconButton(Icons.delete_sweep_outlined, 'Clear all', _clearAll,
                _elements.isEmpty),
          ],
        ),
      ),
    );
  }

  Widget _toolButton(WhiteboardTool tool, IconData icon, String tooltip) {
    final active = _currentTool == tool;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentTool = tool;
            if (tool == WhiteboardTool.hand) {
              _selectedIds = {};
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1971C2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Tooltip(
            message: tooltip,
            child: Icon(icon,
                size: 18,
                color: active ? Colors.white : const Color(0xFF555555)),
          ),
        ),
      ),
    );
  }

  Widget _colorCircle(
      {required Color color, required VoidCallback onTap, bool isFill = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color == Colors.transparent ? Colors.white : color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: color == Colors.transparent
                  ? const Color(0xFFCCCCCC)
                  : color.withAlpha(204),
              width: 2),
        ),
        child: isFill && color == Colors.transparent
            ? Center(
                child: Icon(Icons.close,
                    size: 14, color: const Color(0xFFCCCCCC)))
            : null,
      ),
    );
  }



  Widget _iconButton(
      IconData icon, String tooltip, VoidCallback onTap, bool disabled) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
        child: Tooltip(
          message: tooltip,
          child: Icon(icon,
              size: 16,
              color: disabled
                  ? const Color(0xFFCCCCCC)
                  : const Color(0xFF555555)),
        ),
      ),
    );
  }

  Widget _zoomButton(
      IconData icon, String tooltip, VoidCallback onTap, bool disabled) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Tooltip(
          message: tooltip,
          child: Icon(icon,
              size: 14,
              color: disabled
                  ? const Color(0xFFCCCCCC)
                  : const Color(0xFF555555)),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Text Input Dialog
// ──────────────────────────────────────────────

// ──────────────────────────────────────────────
// HSL Color Picker
// ──────────────────────────────────────────────

class _HslColorPicker extends StatefulWidget {
  final Color currentColor;
  final ValueChanged<Color> onColorChanged;
  final bool includeTransparent;

  const _HslColorPicker({
    required this.currentColor,
    required this.onColorChanged,
    this.includeTransparent = false,
  });

  @override
  State<_HslColorPicker> createState() => _HslColorPickerState();
}

class _HslColorPickerState extends State<_HslColorPicker> {
  late double _hue;
  late double _saturation;
  late double _value;
  late double _alpha;
  late TextEditingController _hexController;

  static const _presetColors = [
    Color(0xFF000000),
    Color(0xFF1E1E1E),
    Color(0xFF555555),
    Color(0xFF888888),
    Color(0xFFCCCCCC),
    Color(0xFFFFFFFF),
    Color(0xFFE03131),
    Color(0xFFE8590C),
    Color(0xFFF08C00),
    Color(0xFFF59F00),
    Color(0xFF94D82D),
    Color(0xFF2F9E44),
    Color(0xFF20C997),
    Color(0xFF1098AD),
    Color(0xFF1971C2),
    Color(0xFF5C7CFA),
    Color(0xFF7950F2),
    Color(0xFFAE3EC9),
    Color(0xFFF06595),
    Color(0xFFFF8787),
  ];

  @override
  void initState() {
    super.initState();
    _initFromColor(widget.currentColor);
    _hexController = TextEditingController(text: _colorToHex(widget.currentColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _initFromColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    _hue = hsl.hue;
    _saturation = hsl.saturation;
    _value = color.computeLuminance(); // approximate
    _alpha = color.a;
    // Better: use HSV
    final r = color.r;
    final g = color.g;
    final b = color.b;
    final maxC = max(r, max(g, b));
    final minC = min(r, min(g, b));
    final delta = maxC - minC;
    _value = maxC;
    _saturation = maxC == 0 ? 0 : delta / maxC;
  }

  String _colorToHex(Color c) {
    return '#${(c.r * 255).round().toRadixString(16).padLeft(2, '0')}'
        '${(c.g * 255).round().toRadixString(16).padLeft(2, '0')}'
        '${(c.b * 255).round().toRadixString(16).padLeft(2, '0')}';
  }

  Color _fromHSV(double h, double s, double v) {
    return HSVColor.fromAHSV(_alpha, h, s, v).toColor();
  }

  void _updateColor() {
    final color = _fromHSV(_hue, _saturation, _value);
    _hexController.text = _colorToHex(color);
    widget.onColorChanged(color);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 2D Saturation/Value picker
          _buildSaturationValuePicker(),
          const SizedBox(height: 8),
          // Hue slider
          _buildHueSlider(),
          const SizedBox(height: 10),
          // Preview + Hex input
          Row(
            children: [
              // Color preview
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _fromHSV(_hue, _saturation, _value),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDDDDDD), width: 1),
                ),
              ),
              const SizedBox(width: 8),
              // Hex input
              Expanded(
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F3F3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _hexController,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: const Color(0xFF1E1E1E),
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                    onSubmitted: (value) {
                      final hex = value.replaceAll('#', '').trim();
                      if (hex.length == 6) {
                        final c = Color(int.parse('FF$hex', radix: 16));
                        _initFromColor(c);
                        setState(() {});
                        _updateColor();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Preset colors
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (widget.includeTransparent)
                GestureDetector(
                  onTap: () => widget.onColorChanged(Colors.transparent),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFFCCCCCC)),
                    ),
                    child: Center(
                      child: Icon(Icons.close, size: 11, color: const Color(0xFFCCCCCC)),
                    ),
                  ),
                ),
              ..._presetColors.map((c) => GestureDetector(
                    onTap: () {
                      _initFromColor(c);
                      setState(() {});
                      _updateColor();
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: c == Colors.white ? const Color(0xFFCCCCCC) : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                    ),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaturationValuePicker() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        return GestureDetector(
          onPanDown: (d) => _onSaturationValueTap(d.localPosition, size),
          onPanUpdate: (d) => _onSaturationValueTap(d.localPosition, size),
          child: Container(
            width: size,
            height: size * 0.6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: CustomPaint(
                painter: _SaturationValuePainter(
                    hue: _hue,
                    saturation: _saturation,
                    value: _value),
                size: Size(size, size * 0.6),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onSaturationValueTap(Offset position, double totalWidth) {
    final size = Size(totalWidth, totalWidth * 0.6);
    setState(() {
      _saturation = (position.dx / size.width).clamp(0.0, 1.0);
      _value = 1.0 - (position.dy / size.height).clamp(0.0, 1.0);
    });
    _updateColor();
  }

  Widget _buildHueSlider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          onPanDown: (d) => _onHueTap(d.localPosition, width),
          onPanUpdate: (d) => _onHueTap(d.localPosition, width),
          child: Container(
            width: width,
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: CustomPaint(
                painter: _HueSliderPainter(hue: _hue),
                size: Size(width, 14),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onHueTap(Offset position, double totalWidth) {
    setState(() {
      _hue = (position.dx / totalWidth * 360).clamp(0.0, 360.0);
    });
    _updateColor();
  }
}

// ── Sat/Value Painter ──

class _SaturationValuePainter extends CustomPainter {
  final double hue;
  final double saturation;
  final double value;

  _SaturationValuePainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final baseColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();

    // Draw base hue color
    canvas.drawRect(
        Offset.zero & size, Paint()..color = baseColor);

    // White saturation gradient (left → right)
    final satRect = Offset.zero & size;
    final satGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Colors.white, Colors.transparent],
    );
    canvas.drawRect(satRect, Paint()..shader = satGradient.createShader(satRect));

    // Black value gradient (bottom → top)
    final valGradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [Colors.black, Colors.transparent],
    );
    canvas.drawRect(satRect, Paint()..shader = valGradient.createShader(satRect));

    // Draw crosshair
    final cx = saturation * size.width;
    final cy = (1.0 - value) * size.height;
    final crossColor = value > 0.6 && saturation < 0.5
        ? Colors.black
        : Colors.white;
    final crossPaint = Paint()
      ..color = crossColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, cy), 6, crossPaint);
    canvas.drawCircle(Offset(cx, cy), 5, Paint()..color = crossColor.withAlpha(60));
  }

  @override
  bool shouldRepaint(covariant _SaturationValuePainter oldDelegate) =>
      oldDelegate.hue != hue ||
      oldDelegate.saturation != saturation ||
      oldDelegate.value != value;
}

// ── Hue Slider Painter ──

class _HueSliderPainter extends CustomPainter {
  final double hue;

  _HueSliderPainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      colors: [
        const Color(0xFFFF0000),
        const Color(0xFFFFFF00),
        const Color(0xFF00FF00),
        const Color(0xFF00FFFF),
        const Color(0xFF0000FF),
        const Color(0xFFFF00FF),
        const Color(0xFFFF0000),
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    // Draw indicator
    final ix = (hue / 360) * size.width;
    final indicatorPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(ix, 0), Offset(ix, size.height), indicatorPaint);
    // Border
    final borderPaint = Paint()
      ..color = Colors.white.withAlpha(80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _HueSliderPainter oldDelegate) =>
      oldDelegate.hue != hue;
}

class _TextInputDialog extends StatefulWidget {
  final String initialText;
  final ValueChanged<String> onDone;

  const _TextInputDialog({required this.initialText, required this.onDone});

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focusNode = FocusNode();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E8E8)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(30),
                blurRadius: 24,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.text_fields_rounded,
                    size: 16, color: tokens.textPrimary),
                const SizedBox(width: 8),
                Text('Enter Text',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: 5,
              minLines: 1,
              style: GoogleFonts.architectsDaughter(
                  fontSize: 16,
                  color: const Color(0xFF1E1E1E),
                  height: 1.4),
              decoration: InputDecoration(
                hintText: 'Type something...',
                hintStyle: GoogleFonts.architectsDaughter(
                    fontSize: 16, color: const Color(0xFFBBBBBB)),
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(12),
              ),
              onSubmitted: (_) {
                widget.onDone(_controller.text);
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () {
                    widget.onDone(_controller.text);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [tokens.accent, tokens.accentSecondary]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Done',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF3F3F3),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('Cancel',
                        style: TextStyle(
                            fontSize: 12, color: const Color(0xFF888888))),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Whiteboard Export Dialog
// ──────────────────────────────────────────────

class WhiteboardExportDialog extends StatefulWidget {
  final Future<Uint8List?> Function(bool isHorizontal) onGenerate;
  final VoidCallback onCancel;

  const WhiteboardExportDialog({
    super.key,
    required this.onGenerate,
    required this.onCancel,
  });

  @override
  State<WhiteboardExportDialog> createState() => _WhiteboardExportDialogState();
}

class _WhiteboardExportDialogState extends State<WhiteboardExportDialog> {
  bool isHorizontal = true;
  Uint8List? previewBytes;
  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      isLoading = true;
    });
    final bytes = await widget.onGenerate(isHorizontal);
    if (mounted) {
      setState(() {
        previewBytes = bytes;
        isLoading = false;
      });
    }
  }

  Future<void> _saveFile() async {
    if (previewBytes == null || isSaving) return;

    setState(() {
      isSaving = true;
    });

    try {
      final String? outputFile = await FilePicker.saveFile(
        dialogTitle: 'Select destination to save image:',
        fileName: isHorizontal ? 'whiteboard_landscape.png' : 'whiteboard_portrait.png',
        allowedExtensions: ['png'],
        type: FileType.custom,
        bytes: previewBytes,
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(previewBytes!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Whiteboard artwork exported successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        widget.onCancel(); // close dialog
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save file: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final width = MediaQuery.of(context).size.width.clamp(400.0, 820.0);

    return Container(
      width: width,
      height: 520,
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tokens.borderMedium, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            spreadRadius: 4,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
            ),
            child: Row(
              children: [
                Icon(Icons.image_search_rounded, color: tokens.accent, size: 24),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export Whiteboard Artwork',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: tokens.textPrimary,
                      ),
                    ),
                    Text(
                      'Preview your artwork layout before exporting to your device',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: tokens.textSecondary, size: 20),
                  onPressed: widget.onCancel,
                  splashRadius: 18,
                ),
              ],
            ),
          ),

          // Body Content
          Expanded(
            child: Row(
              children: [
                // Left Panel: Options & Controls
                Container(
                  width: 300,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: tokens.borderSubtle)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IMAGE ORIENTATION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: tokens.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _OrientationCard(
                              title: 'Horizontal',
                              subtitle: 'Landscape 1.6:1',
                              icon: Icons.crop_landscape_rounded,
                              isSelected: isHorizontal,
                              onTap: () {
                                if (!isHorizontal) {
                                  setState(() {
                                    isHorizontal = true;
                                  });
                                  _loadPreview();
                                }
                              },
                              tokens: tokens,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _OrientationCard(
                              title: 'Vertical',
                              subtitle: 'Portrait 1:1.6',
                              icon: Icons.crop_portrait_rounded,
                              isSelected: !isHorizontal,
                              onTap: () {
                                if (isHorizontal) {
                                  setState(() {
                                    isHorizontal = false;
                                  });
                                  _loadPreview();
                                }
                              },
                              tokens: tokens,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Divider(color: tokens.borderSubtle),
                      const SizedBox(height: 16),
                      Text(
                        'EXPORT PARAMETERS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: tokens.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.aspect_ratio_rounded, 'Aspect Ratio', isHorizontal ? '16 : 10' : '10 : 16', tokens),
                      const SizedBox(height: 8),
                      _buildDetailRow(Icons.photo_size_select_large_rounded, 'Resolution', isHorizontal ? '1920 x 1200' : '1200 x 1920', tokens),
                      const SizedBox(height: 8),
                      _buildDetailRow(Icons.fit_screen_rounded, 'Auto-Fit Bounds', 'Enabled (Centered)', tokens),
                      const Spacer(),
                      
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: widget.onCancel,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: tokens.borderMedium),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (isLoading || previewBytes == null || isSaving) ? null : _saveFile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: tokens.accent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(Colors.white),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.download_rounded, size: 16),
                                        SizedBox(width: 6),
                                        Text('Download', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Right Panel: Live Preview Display
                Expanded(
                  child: Container(
                    color: tokens.background.withValues(alpha: 0.5),
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: tokens.borderMedium),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                children: [
                                  if (isLoading)
                                    Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation(tokens.accent),
                                      ),
                                    )
                                  else if (previewBytes != null)
                                    Center(
                                      child: Container(
                                        margin: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.3),
                                              blurRadius: 16,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: Image.memory(
                                          previewBytes!,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    )
                                  else
                                    Center(
                                      child: Text(
                                        'No Preview Available',
                                        style: TextStyle(color: tokens.textMuted, fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Vector render preview (Aspect Ratio fits all drawn contents)',
                            style: TextStyle(fontSize: 9.5, color: tokens.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, ThemeTokens tokens) {
    return Row(
      children: [
        Icon(icon, size: 14, color: tokens.textMuted),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(fontSize: 11, color: tokens.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.textPrimary),
        ),
      ],
    );
  }
}

class _OrientationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeTokens tokens;

  const _OrientationCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? tokens.accent.withValues(alpha: 0.12)
              : tokens.background.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? tokens.accent : tokens.borderSubtle,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? tokens.accent : tokens.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? tokens.accent : tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 8.5,
                color: tokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── History Bar Painter ──
class _HistoryBarPainter extends CustomPainter {
  final int totalSlots;
  final int filledCount;
  final int maxVisible;

  _HistoryBarPainter({
    required this.totalSlots,
    required this.filledCount,
    required this.maxVisible,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = (size.width - (maxVisible - 1) * 3) / maxVisible;
    final count = filledCount.clamp(0, maxVisible);

    for (int i = 0; i < maxVisible; i++) {
      final x = i * (barWidth + 3);
      final isFilled = i < count;
      final paint = Paint()
        ..color = isFilled
            ? (i == count - 1
                ? const Color(0xFF1971C2)
                : const Color(0xFF1971C2).withAlpha(80))
            : const Color(0xFFE8E8E8)
        ..style = PaintingStyle.fill;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - i % 2 * 6 - 8, barWidth, 8 + i % 2 * 6),
        const Radius.circular(2),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HistoryBarPainter oldDelegate) =>
      oldDelegate.filledCount != filledCount;
}