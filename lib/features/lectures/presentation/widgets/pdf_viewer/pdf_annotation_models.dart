import 'dart:convert';

import 'package:material_ui/material_ui.dart';

enum PdfToolMode { scroll, highlight, text, note }

class AnnotationEditResult<T> {
  const AnnotationEditResult.save(this.value) : delete = false;
  const AnnotationEditResult.delete() : value = null, delete = true;

  final T? value;
  final bool delete;
}

class HighlightStroke {
  HighlightStroke({
    required this.id,
    required this.points,
    required this.color,
    this.strokeWidth = 10,
  });

  final String id;
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  Map<String, dynamic> toJson() => {
    'id': id,
    'points': points.map((point) => {'x': point.dx, 'y': point.dy}).toList(),
    'color': color.toARGB32(),
    'strokeWidth': strokeWidth,
  };

  factory HighlightStroke.fromJson(Map<String, dynamic> json) =>
      HighlightStroke(
        id:
            json['id'] as String? ??
            'highlight_${DateTime.now().microsecondsSinceEpoch}',
        points: (json['points'] as List<dynamic>? ?? const [])
            .map(
              (point) => Offset(
                (point['x'] as num).toDouble(),
                (point['y'] as num).toDouble(),
              ),
            )
            .toList(),
        color: Color((json['color'] as num?)?.toInt() ?? 0x66FFEB3B),
        strokeWidth: _normalizedStrokeWidth(json['strokeWidth']),
      );

  static double _normalizedStrokeWidth(dynamic value) {
    final width = (value as num?)?.toDouble() ?? .022;
    // A previous reader accidentally persisted normalized widths as 7..12.
    if (width > .2) return .022;
    return width.clamp(.002, .1).toDouble();
  }
}

class PdfTextAnnotation {
  PdfTextAnnotation({
    required this.id,
    required this.pageIndex,
    required this.position,
    required this.text,
    this.color = const Color(0xFF512DA8),
    this.fontSize = 14,
    this.hasBackground = true,
  });

  final String id;
  final int pageIndex;
  Offset position;
  String text;
  Color color;
  double fontSize;
  bool hasBackground;

  PdfTextAnnotation copy() => PdfTextAnnotation.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'id': id,
    'pageIndex': pageIndex,
    'x': position.dx,
    'y': position.dy,
    'text': text,
    'color': color.toARGB32(),
    'fontSize': fontSize,
    'hasBackground': hasBackground,
  };

  factory PdfTextAnnotation.fromJson(Map<String, dynamic> json) =>
      PdfTextAnnotation(
        id:
            json['id'] as String? ??
            'text_${DateTime.now().microsecondsSinceEpoch}',
        pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
        position: Offset(
          (json['x'] as num?)?.toDouble() ?? 40,
          (json['y'] as num?)?.toDouble() ?? 40,
        ),
        text: json['text'] as String? ?? '',
        color: Color((json['color'] as num?)?.toInt() ?? 0xFF512DA8),
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 14,
        hasBackground: json['hasBackground'] as bool? ?? true,
      );
}

class PdfNote {
  PdfNote({
    required this.id,
    required this.pageIndex,
    required this.position,
    required this.text,
    required this.color,
    required this.createdAt,
    this.size = 140,
    this.isPinned = false,
    this.isCollapsed = false,
  });

  final String id;
  final int pageIndex;
  Offset position;
  String text;
  Color color;
  final DateTime createdAt;
  double size;
  bool isPinned;
  bool isCollapsed;

  PdfNote copy() => PdfNote.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'id': id,
    'pageIndex': pageIndex,
    'x': position.dx,
    'y': position.dy,
    'text': text,
    'color': color.toARGB32(),
    'createdAt': createdAt.toIso8601String(),
    'size': size,
    'isPinned': isPinned,
    'isCollapsed': isCollapsed,
  };

  factory PdfNote.fromJson(Map<String, dynamic> json) {
    final rawSize = (json['size'] as num?)?.toDouble() ?? 140;
    final safeSize = rawSize < 60 ? 140.0 : rawSize.clamp(70, 320).toDouble();
    return PdfNote(
      id:
          json['id'] as String? ??
          'note_${DateTime.now().microsecondsSinceEpoch}',
      pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
      position: Offset(
        (json['x'] as num?)?.toDouble() ?? 40,
        (json['y'] as num?)?.toDouble() ?? 40,
      ),
      text: json['text'] as String? ?? '',
      color: Color((json['color'] as num?)?.toInt() ?? 0xFFFFFFFF),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      size: safeSize,
      isPinned: json['isPinned'] as bool? ?? false,
      isCollapsed: json['isCollapsed'] as bool? ?? false,
    );
  }
}

class PdfAnnotationDocument {
  PdfAnnotationDocument();

  static const currentCoordinateVersion = 3;
  int coordinateVersion = currentCoordinateVersion;

  final Map<int, List<HighlightStroke>> highlights = {};
  final Map<int, List<PdfTextAnnotation>> texts = {};
  final Map<int, List<PdfNote>> notes = {};

  bool get isEmpty => highlights.isEmpty && texts.isEmpty && notes.isEmpty;

  Map<String, dynamic> toJson() => {
    'version': currentCoordinateVersion,
    'highlights': _encodePages(highlights, (item) => item.toJson()),
    'texts': _encodePages(texts, (item) => item.toJson()),
    'notes': _encodePages(notes, (item) => item.toJson()),
    'savedAt': DateTime.now().toIso8601String(),
  };

  String snapshot() => jsonEncode(toJson());

  void restore(String value) => replaceWith(
    PdfAnnotationDocument.fromJson(
      Map<String, dynamic>.from(jsonDecode(value) as Map),
    ),
  );

  void replaceWith(PdfAnnotationDocument other) {
    highlights
      ..clear()
      ..addAll(other.highlights);
    texts
      ..clear()
      ..addAll(other.texts);
    notes
      ..clear()
      ..addAll(other.notes);
  }

  factory PdfAnnotationDocument.fromJson(Map<String, dynamic> json) {
    final document = PdfAnnotationDocument();
    final version = (json['version'] as num?)?.toInt() ?? 1;
    // Legacy annotations were stored in viewport/native-view coordinates.
    // Those coordinates cannot be converted reliably after zoom or relayout.
    if (version < currentCoordinateVersion) return document;
    document.coordinateVersion = version;
    _decodePages(
      json['highlights'],
      document.highlights,
      HighlightStroke.fromJson,
    );
    _decodePages(json['texts'], document.texts, PdfTextAnnotation.fromJson);
    _decodePages(json['notes'], document.notes, PdfNote.fromJson);
    return document;
  }

  static Map<String, dynamic> _encodePages<T>(
    Map<int, List<T>> source,
    Map<String, dynamic> Function(T) encode,
  ) => source.map(
    (page, items) => MapEntry(page.toString(), items.map(encode).toList()),
  );

  static void _decodePages<T>(
    dynamic raw,
    Map<int, List<T>> target,
    T Function(Map<String, dynamic>) decode,
  ) {
    if (raw is! Map<String, dynamic>) return;
    raw.forEach((page, items) {
      if (items is! List) return;
      target[int.tryParse(page) ?? 0] = items
          .whereType<Map>()
          .map((item) => decode(Map<String, dynamic>.from(item)))
          .toList();
    });
  }
}
