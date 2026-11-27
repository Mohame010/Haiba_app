import 'package:material_ui/material_ui.dart';

import 'pdf_annotation_models.dart';
import 'pdf_editor_controller.dart';

/// An annotation surface whose coordinate space is the PDF page itself.
/// Every stored point is normalized (0..1), so zoom and layout never move it.
class PdfPageAnnotationLayer extends StatelessWidget {
  const PdfPageAnnotationLayer({
    super.key,
    required this.controller,
    required this.pageIndex,
    required this.onAddText,
    required this.onEditText,
    required this.onAddNote,
    required this.onEditNote,
    required this.onHighlightDeleted,
  });

  final PdfEditorController controller;
  final int pageIndex;
  final void Function(int page, Offset position) onAddText;
  final ValueChanged<PdfTextAnnotation> onEditText;
  final void Function(int page, Offset position) onAddNote;
  final ValueChanged<PdfNote> onEditNote;
  final VoidCallback onHighlightDeleted;

  Offset _normalized(Offset local, Size size) => Offset(
    (local.dx / size.width).clamp(0, 1).toDouble(),
    (local.dy / size.height).clamp(0, 1).toDouble(),
  );

  Offset _display(Offset normalized, Size size) =>
      Offset(normalized.dx * size.width, normalized.dy * size.height);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      return Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            ignoring: controller.tool == PdfToolMode.scroll,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _tap(details.localPosition, size),
              onPanStart: controller.tool == PdfToolMode.highlight
                  ? (details) => controller.beginHighlight(
                      pageIndex,
                      _normalized(details.localPosition, size),
                      // Width belongs to the PDF page, not to the current zoom.
                      .022,
                    )
                  : null,
              onPanUpdate: controller.tool == PdfToolMode.highlight
                  ? (details) => controller.extendHighlight(
                      _normalized(details.localPosition, size),
                    )
                  : null,
              onPanEnd: controller.tool == PdfToolMode.highlight
                  ? (_) => controller.finishHighlight()
                  : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: PdfHighlightPainter(
                        revision: controller.paintRevision,
                        savedStrokes: controller.highlightsFor(pageIndex),
                        activeStroke: controller.currentPage == pageIndex
                            ? controller.activeStroke
                            : null,
                      ),
                    ),
                  ),
                  for (final text in controller.textsFor(pageIndex))
                    _textAnnotation(text, size),
                ],
              ),
            ),
          ),
          // Notes remain interactive while reading. Dragging outside a note
          // continues to be handled by the underlying PDF viewer.
          for (final note in controller.notesFor(pageIndex))
            _noteAnnotation(note, size),
        ],
      );
    },
  );

  void _tap(Offset localPosition, Size size) {
    final position = _normalized(localPosition, size);
    switch (controller.tool) {
      case PdfToolMode.highlight:
        if (controller.deleteHighlightAt(
          pageIndex,
          position,
          10 / size.width,
        )) {
          onHighlightDeleted();
        }
      case PdfToolMode.text:
        onAddText(pageIndex, position);
      case PdfToolMode.note:
        onAddNote(pageIndex, position);
      case PdfToolMode.scroll:
        break;
    }
  }

  Widget _textAnnotation(PdfTextAnnotation annotation, Size size) {
    final position = _display(annotation.position, size);
    final displayScale = (size.width / 360).clamp(.7, 4).toDouble();
    final effectiveFontSize = (annotation.fontSize * displayScale).clamp(
      2.0,
      120.0,
    );
    final isVerySmall = annotation.fontSize <= 8;
    final isUltraSmall = annotation.fontSize <= 3;
    final touchMargin = isVerySmall ? 8.0 : 0.0;
    return Positioned(
      left: position.dx - touchMargin,
      top: position.dy - touchMargin,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onEditText(annotation),
        onScaleStart: (_) => controller.beginTextTransform(annotation),
        onScaleUpdate: (details) => controller.transformText(
          annotation,
          Offset(
            details.focalPointDelta.dx / size.width,
            details.focalPointDelta.dy / size.height,
          ),
          details.scale,
        ),
        onScaleEnd: (_) => controller.finishTransform(),
        child: Container(
          color: Colors.transparent,
          padding: EdgeInsets.all(touchMargin),
          child: Container(
            constraints: BoxConstraints(maxWidth: 220 * displayScale),
            padding: EdgeInsets.symmetric(
              horizontal:
                  (isUltraSmall ? 1.5 : (isVerySmall ? 3 : 7)) * displayScale,
              vertical:
                  (isUltraSmall ? 0.5 : (isVerySmall ? 2 : 4)) * displayScale,
            ),
            decoration: BoxDecoration(
              color: annotation.hasBackground
                  ? const Color(0xFFFFF8C5).withValues(alpha: .92)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(
                (isUltraSmall ? 2 : (isVerySmall ? 3 : 6)) * displayScale,
              ),
              border: Border.all(
                color: annotation.hasBackground
                    ? const Color(0xFFFFCC80)
                    : Colors.transparent,
                width: isVerySmall ? 0.5 : 1,
              ),
            ),
            child: Text(
              annotation.text,
              style: TextStyle(
                color: annotation.color,
                fontSize: effectiveFontSize,
                fontFamily: 'IBM',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _noteAnnotation(PdfNote note, Size size) {
    final position = _display(note.position, size);
    final displayScale = (size.width / 360).clamp(.7, 4).toDouble();
    if (note.isCollapsed) {
      final buttonSize = (38 * displayScale).clamp(34.0, 52.0);
      final iconSize = (20 * displayScale).clamp(18.0, 26.0);
      return Positioned(
        left: position.dx,
        top: position.dy,
        child: Tooltip(
          message: 'إظهار الملاحظة',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('collapsed_pdf_note_${note.id}'),
              onTap: () => controller.toggleNoteCollapsed(note),
              borderRadius: BorderRadius.circular(buttonSize / 2),
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF6D28D9),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(90),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: const Color(0xFF6D28D9).withAlpha(100),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.visibility_off_rounded,
                    color: Colors.white,
                    size: iconSize,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final noteWidth = (note.size * displayScale).clamp(
      110.0,
      size.width * 0.85,
    );
    final fontSize = (11.0 * displayScale).clamp(9.0, 20.0);

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onEditNote(note),
        onScaleStart: controller.tool == PdfToolMode.scroll
            ? null
            : (_) => controller.beginNoteTransform(note),
        onScaleUpdate: controller.tool == PdfToolMode.scroll
            ? null
            : (details) {
                if (note.isPinned) return;
                controller.transformNote(
                  note,
                  Offset(
                    details.focalPointDelta.dx / size.width,
                    details.focalPointDelta.dy / size.height,
                  ),
                  details.scale,
                );
              },
        onScaleEnd: controller.tool == PdfToolMode.scroll
            ? null
            : (_) => controller.finishTransform(),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: noteWidth,
            constraints: BoxConstraints(minHeight: 70 * displayScale),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10 * displayScale),
              border: Border.all(
                color: note.isPinned
                    ? const Color(0xFFFDA4AF)
                    : const Color(0xFFCBD5E1),
                width: note.isPinned ? 1.5 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .12),
                  blurRadius: 10 * displayScale,
                  offset: Offset(0, 4 * displayScale),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: .04),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Notebook Header Strip
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8 * displayScale,
                    vertical: 4 * displayScale,
                  ),
                  decoration: BoxDecoration(
                    color: note.isPinned
                        ? const Color(0xFFFFF1F2)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(9 * displayScale),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: note.isPinned
                            ? const Color(0xFFFECDD3)
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Spiral notebook binding holes
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < 3; i++) ...[
                            Container(
                              width: 5 * displayScale,
                              height: 5 * displayScale,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            if (i < 2) SizedBox(width: 3 * displayScale),
                          ],
                        ],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          note.isPinned ? 'مثبتة 📌' : 'ورقة ملاحظات',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'IBM',
                            fontSize: (9.5 * displayScale).clamp(8.0, 14.0),
                            fontWeight: FontWeight.w700,
                            color: note.isPinned
                                ? const Color(0xFFE11D48)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      // Pin / Unpin Button
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => controller.toggleNotePin(note),
                        child: Container(
                          padding: EdgeInsets.all(2 * displayScale),
                          child: Icon(
                            note.isPinned
                                ? Icons.push_pin_rounded
                                : Icons.push_pin_outlined,
                            size: (16 * displayScale).clamp(13.0, 24.0),
                            color: note.isPinned
                                ? const Color(0xFFE11D48)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      Tooltip(
                        message: 'إخفاء الملاحظة وإظهار علامة القلم',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => controller.toggleNoteCollapsed(note),
                          child: Padding(
                            padding: EdgeInsets.all(2 * displayScale),
                            child: Icon(
                              Icons.visibility_off_rounded,
                              size: (16 * displayScale).clamp(13.0, 24.0),
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Lined notebook page body
                CustomPaint(
                  painter: _NotebookLinesPainter(
                    lineSpacing: (18 * displayScale).clamp(14.0, 32.0),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8 * displayScale,
                      vertical: 6 * displayScale,
                    ),
                    child: Text(
                      note.text.isEmpty ? 'انقر لكتابة ملاحظتك...' : note.text,
                      style: TextStyle(
                        fontFamily: 'IBM',
                        fontSize: fontSize,
                        height: 1.45,
                        color: note.text.isEmpty
                            ? Colors.black26
                            : const Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotebookLinesPainter extends CustomPainter {
  const _NotebookLinesPainter({required this.lineSpacing});

  final double lineSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 0.8;
    for (double y = lineSpacing; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NotebookLinesPainter oldDelegate) =>
      oldDelegate.lineSpacing != lineSpacing;
}

class PdfHighlightPainter extends CustomPainter {
  const PdfHighlightPainter({
    required this.revision,
    required this.savedStrokes,
    required this.activeStroke,
  });

  final int revision;
  final List<HighlightStroke> savedStrokes;
  final HighlightStroke? activeStroke;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in savedStrokes) {
      _draw(canvas, size, stroke);
    }
    if (activeStroke != null) _draw(canvas, size, activeStroke!);
  }

  void _draw(Canvas canvas, Size size, HighlightStroke stroke) {
    if (stroke.points.isEmpty) return;
    final paint = Paint()
      ..color = stroke.color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = stroke.strokeWidth * size.width
      ..style = PaintingStyle.stroke;
    final points = stroke.points
        .map((point) => Offset(point.dx * size.width, point.dy * size.height))
        .toList(growable: false);
    if (points.length == 1) {
      canvas.drawCircle(
        points.first,
        paint.strokeWidth / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length - 1; index++) {
      final point = points[index];
      final next = points[index + 1];
      final middle = Offset((point.dx + next.dx) / 2, (point.dy + next.dy) / 2);
      path.quadraticBezierTo(point.dx, point.dy, middle.dx, middle.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant PdfHighlightPainter oldDelegate) =>
      revision != oldDelegate.revision ||
      savedStrokes != oldDelegate.savedStrokes ||
      activeStroke != oldDelegate.activeStroke;
}
