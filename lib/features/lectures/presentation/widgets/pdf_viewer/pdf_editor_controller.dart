import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'pdf_annotation_models.dart';
import 'pdf_document_store.dart';

class PdfEditorController extends ChangeNotifier {
  PdfEditorController({
    required this.url,
    required this.title,
    this.store = const PdfDocumentStore(),
  });

  final String url;
  final String title;
  final PdfDocumentStore store;
  final PdfAnnotationDocument document = PdfAnnotationDocument();

  String? localPath;
  String? annotationPath;
  String? error;
  double? loadingProgress;
  bool loading = true;
  int currentPage = 0;
  int totalPages = 0;
  PdfToolMode tool = PdfToolMode.scroll;
  Color color = const Color(0xFFFFEB3B);
  HighlightStroke? activeStroke;
  int paintRevision = 0;
  double preferredFontSize = 12;

  final List<String> _undoStack = [];
  String? _pendingSnapshot;
  Timer? _saveTimer;
  int? _activeStrokePage;
  double? _transformStartSize;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get availableOffline => localPath != null;
  List<HighlightStroke> highlightsFor(int page) =>
      document.highlights[page] ?? const [];
  List<PdfTextAnnotation> textsFor(int page) =>
      document.texts[page] ?? const [];
  List<PdfNote> notesFor(int page) => document.notes[page] ?? const [];

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final prepared = await store.prepare(
        url: url,
        title: title,
        onProgress: (value) {
          loadingProgress = value;
          notifyListeners();
        },
      );
      localPath = prepared.pdfPath;
      annotationPath = prepared.annotationPath;
      document.replaceWith(prepared.annotations);
    } catch (exception) {
      error = exception.toString();
    } finally {
      loading = false;
      loadingProgress = null;
      notifyListeners();
    }
  }

  void setTool(PdfToolMode value) {
    if (tool == value) return;
    activeStroke = null;
    tool = value;
    notifyListeners();
  }

  void setColor(Color value) {
    color = value;
    notifyListeners();
  }

  void setPage(int value) {
    if (currentPage == value) return;
    currentPage = value;
    activeStroke = null;
    paintRevision++;
    notifyListeners();
  }

  void setTotalPages(int value) {
    if (totalPages == value) return;
    totalPages = value;
    notifyListeners();
  }

  void beginHighlight(int page, Offset position, double strokeWidth) {
    currentPage = page;
    _pendingSnapshot = document.snapshot();
    _activeStrokePage = page;
    activeStroke = HighlightStroke(
      id: 'highlight_${DateTime.now().microsecondsSinceEpoch}',
      points: [position],
      color: color.withValues(alpha: .38),
      strokeWidth: strokeWidth,
    );
    paintRevision++;
    notifyListeners();
  }

  void extendHighlight(Offset position) {
    final stroke = activeStroke;
    if (stroke == null) return;
    if (stroke.points.isEmpty ||
        (stroke.points.last - position).distance > .0025) {
      stroke.points.add(position);
      paintRevision++;
      notifyListeners();
    }
  }

  void finishHighlight() {
    final stroke = activeStroke;
    final page = _activeStrokePage;
    if (stroke == null || page == null) return;
    document.highlights.putIfAbsent(page, () => []).add(stroke);
    activeStroke = null;
    _activeStrokePage = null;
    paintRevision++;
    _commitPendingSnapshot();
  }

  bool deleteHighlightAt(int page, Offset position, double tolerance) {
    final pageHighlights = document.highlights[page];
    if (pageHighlights == null) return false;
    for (var index = pageHighlights.length - 1; index >= 0; index--) {
      if (_strokeContains(pageHighlights[index], position, tolerance)) {
        _pushUndo();
        pageHighlights.removeAt(index);
        _changed();
        return true;
      }
    }
    return false;
  }

  void addText(PdfTextAnnotation annotation) {
    _pushUndo();
    document.texts.putIfAbsent(annotation.pageIndex, () => []).add(annotation);
    _changed();
  }

  void updateText(PdfTextAnnotation original, PdfTextAnnotation edited) {
    _pushUndo();
    original
      ..text = edited.text
      ..color = edited.color
      ..fontSize = edited.fontSize
      ..hasBackground = edited.hasBackground;
    _changed();
  }

  void deleteText(PdfTextAnnotation annotation) {
    _pushUndo();
    document.texts[annotation.pageIndex]?.remove(annotation);
    _changed();
  }

  void addNote(PdfNote note) {
    _pushUndo();
    document.notes.putIfAbsent(note.pageIndex, () => []).add(note);
    _changed();
  }

  void updateNote(PdfNote original, PdfNote edited) {
    _pushUndo();
    original
      ..text = edited.text
      ..size = edited.size
      ..isPinned = edited.isPinned
      ..isCollapsed = edited.isCollapsed;
    _changed();
  }

  void deleteNote(PdfNote note) {
    _pushUndo();
    document.notes[note.pageIndex]?.remove(note);
    _changed();
  }

  void beginMove() => _pendingSnapshot ??= document.snapshot();

  void moveText(PdfTextAnnotation annotation, Offset normalizedDelta) {
    annotation.position += normalizedDelta;
    notifyListeners();
  }

  void finishMove() => _commitPendingSnapshot();

  void beginTextTransform(PdfTextAnnotation annotation) {
    beginMove();
    _transformStartSize = annotation.fontSize;
  }

  void transformText(
    PdfTextAnnotation annotation,
    Offset normalizedDelta,
    double scale,
  ) {
    annotation.position = _bounded(annotation.position + normalizedDelta);
    final start = _transformStartSize ?? annotation.fontSize;
    double newSize;
    if (scale <= 1.0) {
      // Map pinch inward range [0.3, 1.0] down to min size 2.0 px
      final t = ((scale - 0.3) / 0.7).clamp(0.0, 1.0);
      newSize = 2.0 + (start - 2.0) * math.pow(t, 1.3);
    } else {
      newSize = (start * scale).clamp(2.0, 72.0);
    }
    annotation.fontSize = newSize.clamp(2.0, 72.0).toDouble();
    preferredFontSize = annotation.fontSize;
    notifyListeners();
  }

  void beginNoteTransform(PdfNote note) {
    if (note.isPinned) return;
    beginMove();
    _transformStartSize = note.size;
  }

  void transformNote(PdfNote note, Offset normalizedDelta, double scale) {
    if (note.isPinned) return;
    note.position = _bounded(note.position + normalizedDelta);
    note.size = ((_transformStartSize ?? note.size) * scale)
        .clamp(80, 320)
        .toDouble();
    notifyListeners();
  }

  void moveNote(PdfNote note, Offset normalizedDelta) {
    if (note.isPinned) return;
    note.position = _bounded(note.position + normalizedDelta);
    notifyListeners();
  }

  void toggleNotePin(PdfNote note) {
    _pushUndo();
    note.isPinned = !note.isPinned;
    _changed();
  }

  void toggleNoteCollapsed(PdfNote note) {
    _pushUndo();
    note.isCollapsed = !note.isCollapsed;
    _changed();
  }

  void finishTransform() {
    _transformStartSize = null;
    finishMove();
  }

  void clearPage() {
    if (highlightsFor(currentPage).isEmpty &&
        textsFor(currentPage).isEmpty &&
        notesFor(currentPage).isEmpty) {
      return;
    }
    _pushUndo();
    document.highlights.remove(currentPage);
    document.texts.remove(currentPage);
    document.notes.remove(currentPage);
    _changed();
  }

  bool get canUndoHighlight =>
      canUndo ||
      (document.highlights[currentPage]?.isNotEmpty ?? false) ||
      activeStroke != null;

  void undoHighlight() {
    if (activeStroke != null) {
      activeStroke = null;
      _activeStrokePage = null;
      paintRevision++;
      notifyListeners();
      return;
    }
    if (canUndo) {
      undo();
      return;
    }
    final pageHighlights = document.highlights[currentPage];
    if (pageHighlights != null && pageHighlights.isNotEmpty) {
      _pushUndo();
      pageHighlights.removeLast();
      _changed();
    }
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    document.restore(_undoStack.removeLast());
    activeStroke = null;
    _changed();
  }

  Future<void> saveNow() async {
    _saveTimer?.cancel();
    final path = annotationPath;
    if (path != null) await store.save(path, document);
    final local = localPath;
    if (local != null) {
      await store.recordRecent(
        RecentPdfDocument(
          url: url,
          title: title,
          cachedPath: local,
          openedAt: DateTime.now(),
        ),
      );
    }
  }

  void _pushUndo() {
    _undoStack.add(document.snapshot());
    if (_undoStack.length > 50) _undoStack.removeAt(0);
  }

  void _commitPendingSnapshot() {
    final snapshot = _pendingSnapshot;
    _pendingSnapshot = null;
    if (snapshot != null) {
      _undoStack.add(snapshot);
      if (_undoStack.length > 50) _undoStack.removeAt(0);
    }
    _changed();
  }

  void _changed() {
    paintRevision++;
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), saveNow);
  }

  bool _strokeContains(
    HighlightStroke stroke,
    Offset point,
    double touchTolerance,
  ) {
    final tolerance = (stroke.strokeWidth / 2) + touchTolerance;
    if (stroke.points.length == 1) {
      return (stroke.points.first - point).distance <= tolerance;
    }
    for (var index = 1; index < stroke.points.length; index++) {
      if (_distanceToSegment(
            point,
            stroke.points[index - 1],
            stroke.points[index],
          ) <=
          tolerance) {
        return true;
      }
    }
    return false;
  }

  double _distanceToSegment(Offset point, Offset start, Offset end) {
    final segment = end - start;
    final lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy;
    if (lengthSquared == 0) return (point - start).distance;
    final ratio =
        (((point - start).dx * segment.dx + (point - start).dy * segment.dy) /
                lengthSquared)
            .clamp(0.0, 1.0)
            .toDouble();
    return (point - (start + segment * ratio)).distance;
  }

  Offset _bounded(Offset value) => Offset(
    value.dx.clamp(0.0, 1.0).toDouble(),
    value.dy.clamp(0.0, 1.0).toDouble(),
  );

  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(saveNow());
    super.dispose();
  }
}
