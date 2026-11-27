import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../domain/novel_entities.dart';
import '../../domain/novel_text_alignment.dart';
import '../../domain/novel_word_normalizer.dart';

typedef NovelWordOpenCallback =
    void Function(
      String word,
      GlobalKey anchorKey,
      int sourceStart,
      int sourceEnd,
    );
typedef NovelNoteOpenCallback =
    void Function(String word, GlobalKey anchorKey, String note);

class NovelReaderTextView extends StatefulWidget {
  const NovelReaderTextView({
    super.key,
    required this.chapter,
    required this.scrollController,
    required this.englishFontSize,
    required this.arabicFontSize,
    required this.textColor,
    required this.highlightColor,
    required this.highlightedWords,
    required this.chapterNotes,
    required this.wordKeys,
    required this.activeWordStart,
    required this.activeWordEnd,
    required this.onOpenWord,
    required this.onOpenNote,
    required this.onShowChrome,
    this.pageColor = Colors.white,
    this.primaryColor = AppColors.primary,
  });

  final NovelChapter chapter;
  final ScrollController scrollController;
  final double englishFontSize;
  final double arabicFontSize;
  final Color textColor;
  final Color highlightColor;
  final Set<String> highlightedWords;
  final Map<String, String> chapterNotes;
  final Map<int, GlobalKey> wordKeys;
  final int? activeWordStart;
  final int? activeWordEnd;
  final NovelWordOpenCallback onOpenWord;
  final NovelNoteOpenCallback onOpenNote;
  final VoidCallback onShowChrome;
  final Color pageColor;
  final Color primaryColor;

  @override
  State<NovelReaderTextView> createState() => _NovelReaderTextViewState();
}

class _NovelReaderTextViewState extends State<NovelReaderTextView> {
  // Cached alignment results — recomputed only when the chapter changes.
  String? _cachedChapterId;
  List<String> _englishLines = const [];
  List<String> _arabicLines = const [];
  List<int> _lineOffsets = const [];

  void _ensureAlignmentCached() {
    if (_cachedChapterId == widget.chapter.id) return;
    _cachedChapterId = widget.chapter.id;
    final alignedLines = alignNovelText(
      widget.chapter.text,
      widget.chapter.translation,
    );
    _englishLines = alignedLines.map((line) => line.$1).toList();
    _arabicLines = alignedLines.map((line) => line.$2).toList();
    var searchFrom = 0;
    final offsets = <int>[];
    for (final line in _englishLines) {
      final offset = widget.chapter.text.indexOf(line, searchFrom);
      offsets.add(offset < 0 ? searchFrom : offset);
      searchFrom = (offset < 0 ? searchFrom : offset) + line.length;
    }
    _lineOffsets = offsets;
  }

  @override
  Widget build(BuildContext context) {
    _ensureAlignmentCached();

    final themeColor = widget.primaryColor;
    final isDark =
        ThemeData.estimateBrightnessForColor(widget.pageColor) ==
        Brightness.dark;

    // Guaranteed High Contrast & Harmonious Rule Color:
    // Deriving the line directly between pageColor and textColor guarantees
    // that the line will NEVER blend into the page or clash with any custom background.
    final baseRule = Color.lerp(
      widget.pageColor,
      widget.textColor,
      isDark ? 0.22 : 0.14,
    )!;
    final notebookRuleColor = Color.lerp(baseRule, themeColor, 0.22)!;

    // Ensure Chapter Title contrast against pageColor:
    final titleLum = themeColor.computeLuminance();
    final pageLum = widget.pageColor.computeLuminance();
    final titleRatio =
        (math.max(titleLum, pageLum) + 0.05) /
        (math.min(titleLum, pageLum) + 0.05);
    final effectiveTitleColor = titleRatio >= 3.0
        ? themeColor
        : (isDark ? const Color(0xFFDDD6FE) : const Color(0xFF581C87));

    return CustomScrollView(
      scrollCacheExtent: ScrollCacheExtent.pixels(2000),
      controller: widget.scrollController,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            math.max(260.0, MediaQuery.sizeOf(context).height * 0.45),
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Chapter order badge if available
                        if (widget.chapter.order > 0)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: effectiveTitleColor.withValues(
                                alpha: isDark ? 0.20 : 0.08,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: effectiveTitleColor.withValues(
                                  alpha: isDark ? 0.35 : 0.20,
                                ),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.menu_book_rounded,
                                  size: 13,
                                  color: effectiveTitleColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'الفصل ${widget.chapter.order}',
                                  style: TextStyle(
                                    fontFamily: 'IBM',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: effectiveTitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Chapter Title in novel's primary theme color
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              widget.chapter.title,
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'IBM',
                                color: effectiveTitleColor,
                                height: 1.28,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Distinctive stylish underline below chapter title
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 3.5,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    effectiveTitleColor,
                                    effectiveTitleColor.withValues(alpha: 0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                    color: effectiveTitleColor.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1.5),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 14,
                              height: 3.5,
                              decoration: BoxDecoration(
                                color: effectiveTitleColor.withValues(
                                  alpha: 0.45,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              width: 5,
                              height: 3.5,
                              decoration: BoxDecoration(
                                color: effectiveTitleColor.withValues(
                                  alpha: 0.25,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      effectiveTitleColor.withValues(
                                        alpha: 0.22,
                                      ),
                                      effectiveTitleColor.withValues(
                                        alpha: 0.0,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                final lineIndex = (index - 1) ~/ 2;
                if ((index - 1).isEven) {
                  return RepaintBoundary(
                    child: _EnglishLine(
                      line: _englishLines[lineIndex],
                      sourceOffset: _lineOffsets[lineIndex],
                      fontSize: widget.englishFontSize,
                      textColor: widget.textColor,
                      highlightColor: widget.highlightColor,
                      highlightedWords: widget.highlightedWords,
                      chapterNotes: widget.chapterNotes,
                      wordKeys: widget.wordKeys,
                      activeWordStart: widget.activeWordStart,
                      activeWordEnd: widget.activeWordEnd,
                      pageColor: widget.pageColor,
                      primaryColor: themeColor,
                      ruleColor: notebookRuleColor,
                      onOpenWord: widget.onOpenWord,
                      onOpenNote: widget.onOpenNote,
                      onShowChrome: widget.onShowChrome,
                    ),
                  );
                }

                if (lineIndex >= _arabicLines.length) {
                  return const SizedBox.shrink();
                }

                final translation = _arabicLines[lineIndex];
                return RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 8,
                      bottom: 22,
                      left: 10,
                    ),
                    child: GestureDetector(
                      onTap: widget.onShowChrome,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text(
                              translation.isEmpty
                                  ? 'الترجمة غير متاحة لهذه الجملة'
                                  : translation,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: 'IBM',
                                color: translation.isEmpty
                                    ? widget.textColor.withValues(alpha: .45)
                                    : widget.textColor.withValues(alpha: .72),
                                fontSize: widget.arabicFontSize,
                                height: 1.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Subtle notebook divider between sentences
                          Container(
                            height: 0.8,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  themeColor.withValues(alpha: 0.08),
                                  themeColor.withValues(alpha: 0.01),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              childCount: 1 + _englishLines.length * 2,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false,
            ),
          ),
        ),
      ],
    );
  }
}

/// Paints horizontal notebook ruled lines under each wrapped row of words.
class _NotebookRuledLinesPainter extends CustomPainter {
  const _NotebookRuledLinesPainter({
    required this.lineColor,
    required this.rowHeight,
    required this.runSpacing,
    required this.topOffset,
  });

  final Color lineColor;
  final double rowHeight;
  final double runSpacing;
  final double topOffset;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0 || size.width <= 0) return;

    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final rowStep = rowHeight + runSpacing;
    if (rowStep <= 0) return;

    // The line sits right under each row of words, safely below letter descenders
    final lineFirstY = topOffset + rowHeight + 2.0;

    for (
      double y = lineFirstY;
      y <= size.height + (rowHeight * 0.4);
      y += rowStep
    ) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NotebookRuledLinesPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.rowHeight != rowHeight ||
        oldDelegate.runSpacing != runSpacing ||
        oldDelegate.topOffset != topOffset;
  }
}

class _EnglishLine extends StatelessWidget {
  const _EnglishLine({
    required this.line,
    required this.sourceOffset,
    required this.fontSize,
    required this.textColor,
    required this.highlightColor,
    required this.highlightedWords,
    required this.chapterNotes,
    required this.wordKeys,
    required this.activeWordStart,
    required this.activeWordEnd,
    required this.onOpenWord,
    required this.onOpenNote,
    required this.onShowChrome,
    required this.pageColor,
    required this.primaryColor,
    required this.ruleColor,
  });

  final String line;
  final int sourceOffset;
  final double fontSize;
  final Color textColor;
  final Color highlightColor;
  final Set<String> highlightedWords;
  final Map<String, String> chapterNotes;
  final Map<int, GlobalKey> wordKeys;
  final int? activeWordStart;
  final int? activeWordEnd;
  final NovelWordOpenCallback onOpenWord;
  final NovelNoteOpenCallback onOpenNote;
  final VoidCallback onShowChrome;
  final Color pageColor;
  final Color primaryColor;
  final Color ruleColor;

  @override
  Widget build(BuildContext context) {
    final words = RegExp(r'\S+').allMatches(line);
    const textHeightMultiplier = 1.55;
    const runSpacing = 12.0;
    const topOffset = 6.0;
    final rowHeight = fontSize * textHeightMultiplier;
    final notebookRuleColor = ruleColor;

    final isSentenceSpeaking =
        activeWordStart != null &&
        activeWordEnd != null &&
        activeWordStart! >= sourceOffset &&
        activeWordStart! < sourceOffset + line.length;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isSentenceSpeaking
                ? primaryColor.withValues(alpha: 0.85)
                : primaryColor.withValues(alpha: 0.20),
            width: isSentenceSpeaking ? 2.5 : 1.5,
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: 10),
      child: CustomPaint(
        painter: _NotebookRuledLinesPainter(
          lineColor: isSentenceSpeaking
              ? primaryColor.withValues(alpha: 0.28)
              : notebookRuleColor,
          rowHeight: rowHeight,
          runSpacing: runSpacing,
          topOffset: topOffset,
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(
            spacing: 4,
            runSpacing: runSpacing,
            children: [
              for (final match in words)
                Builder(
                  builder: (wordContext) {
                    final start = sourceOffset + match.start;
                    final end = sourceOffset + match.end;
                    final key = wordKeys.putIfAbsent(start, GlobalKey.new);
                    final word = match.group(0)!;
                    final isSpeaking =
                        start == activeWordStart &&
                        activeWordEnd != null &&
                        activeWordEnd! > start &&
                        activeWordEnd! <= end;
                    final isHighlighted = highlightedWords.contains(
                      normalizeNovelWord(word),
                    );
                    final note = chapterNotes[normalizeNovelWord(word)];
                    return GestureDetector(
                      key: key,
                      onTap: () {
                        onShowChrome();
                        onOpenWord(word, key, start, end);
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: topOffset),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2.5,
                              vertical: 1.5,
                            ),
                            decoration: !isSpeaking && !isHighlighted
                                ? null
                                : BoxDecoration(
                                    color: isSpeaking
                                        ? highlightColor
                                        : highlightColor.withValues(alpha: .52),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: isSpeaking
                                        ? [
                                            BoxShadow(
                                              color: highlightColor.withValues(
                                                alpha: 0.4,
                                              ),
                                              blurRadius: 3,
                                            ),
                                          ]
                                        : null,
                                  ),
                            child: Text(
                              word,
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                fontSize: fontSize,
                                height: textHeightMultiplier,
                                color: textColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (note != null)
                            PositionedDirectional(
                              top: topOffset - 5,
                              end: -3,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  onShowChrome();
                                  onOpenNote(word, key, note);
                                },
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: const Color(0xffffc94a),
                                    borderRadius: BorderRadius.circular(3.5),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 2,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.note_rounded,
                                    size: 9.5,
                                    color: Color(0xff5d4037),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
