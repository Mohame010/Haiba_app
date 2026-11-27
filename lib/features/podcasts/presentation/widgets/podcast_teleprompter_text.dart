import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../novels/domain/novel_entities.dart';
import '../../../novels/domain/novel_text_alignment.dart';
import '../../../novels/domain/novel_word_normalizer.dart';
import '../../data/services/podcast_cache_service.dart';
import '../../domain/entities/podcast_entity.dart';

typedef OnWordTapCallback =
    void Function(String word, NovelWord? dictionaryWord, GlobalKey wordKey);

class _LineTiming {
  const _LineTiming({
    required this.startSeconds,
    required this.endSeconds,
    required this.wordTimings,
  });

  final double startSeconds;
  final double endSeconds;
  final List<({double start, double end})> wordTimings;
}

class PodcastTeleprompterText extends StatefulWidget {
  const PodcastTeleprompterText({
    super.key,
    required this.episode,
    required this.currentSeconds,
    required this.totalDurationSeconds,
    this.isPlaying = true,
    required this.englishFontSize,
    required this.arabicFontSize,
    required this.textColor,
    required this.highlightColor,
    required this.pageColor,
    required this.showTranslation,
    required this.onWordTap,
    this.onLineTap,
  });

  final PodcastEpisode episode;
  final double currentSeconds;
  final int totalDurationSeconds;
  final bool isPlaying;
  final double englishFontSize;
  final double arabicFontSize;
  final Color textColor;
  final Color highlightColor;
  final Color pageColor;
  final bool showTranslation;
  final OnWordTapCallback onWordTap;
  final ValueChanged<double>? onLineTap;

  @override
  State<PodcastTeleprompterText> createState() =>
      _PodcastTeleprompterTextState();
}

class _PodcastTeleprompterTextState extends State<PodcastTeleprompterText> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  // Word keys: keyed by "lineIndex_wordIndex"
  final Map<String, GlobalKey> _wordKeys = {};
  List<(String, String)> _alignedLines = const [];
  List<_LineTiming> _lineTimings = const [];
  int _lastActiveIndex = -1;
  bool _isAutoScrolling = false;
  bool _userInteractingWithScroll = false;
  bool _userScrolledAway = false;
  Timer? _autoResumeScrollTimer;

  @override
  void initState() {
    super.initState();
    _alignContent();
    _loadTimestamps();
  }

  @override
  void didUpdateWidget(covariant PodcastTeleprompterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episode.id != widget.episode.id) {
      _lineKeys.clear();
      _wordKeys.clear();
      _userScrolledAway = false;
      _userInteractingWithScroll = false;
      _autoResumeScrollTimer?.cancel();
      _alignContent();
      _loadTimestamps();
      _autoScrollToActive(force: true);
    } else if (oldWidget.episode.audioTimestampsUrl !=
            widget.episode.audioTimestampsUrl ||
        oldWidget.episode.audioTimestampsData !=
            widget.episode.audioTimestampsData) {
      _loadTimestamps();
    }

    // 1. If playback just started or resumed (e.g. user pressed Play or Replay):
    if (!oldWidget.isPlaying && widget.isPlaying) {
      _userInteractingWithScroll = false;
      _autoResumeScrollTimer?.cancel();
      _autoScrollToActive(force: true);
    }
    // 2. If playback position jump occurred (seeking or restart to 0):
    else if ((oldWidget.currentSeconds - widget.currentSeconds).abs() > 1.2) {
      _userInteractingWithScroll = false;
      _autoResumeScrollTimer?.cancel();
      _autoScrollToActive(force: true);
    }
    // 3. Normal progress tick:
    else {
      _autoScrollToActive();
    }
  }

  void _alignContent() {
    _alignedLines = alignNovelText(
      widget.episode.text,
      widget.episode.translation,
    );
    _buildLineTimings(const []);
  }

  Future<void> _loadTimestamps() async {
    try {
      final cachedOrFetched =
          await PodcastCacheService.instance.getOrFetchTimestamps(widget.episode);
      if (cachedOrFetched != null && mounted) {
        _parseAndApplyTimestamps(cachedOrFetched);
      }
    } catch (e) {
      debugPrint('[PodcastTeleprompterText] Could not load timestamps: $e');
    }
  }

  void _parseAndApplyTimestamps(dynamic raw) {
    if (raw == null) return;
    try {
      final parsedWords = <({String word, double start, double end})>[];

      List<dynamic>? rawList;
      if (raw is List) {
        rawList = raw;
      } else if (raw is Map) {
        if (raw['timestamps'] is List) {
          rawList = raw['timestamps'] as List;
        } else if (raw['words'] is List) {
          rawList = raw['words'] as List;
        } else if (raw['segments'] is List) {
          for (final seg in raw['segments']) {
            if (seg is Map && seg['words'] is List) {
              rawList ??= [];
              rawList.addAll(seg['words'] as List);
            }
          }
        }
      }

      if (rawList != null && rawList.isNotEmpty) {
        // Detect if values are in milliseconds (e.g. 120, 417, 4970) or seconds (0.12, 0.417)
        bool isMs = false;
        for (final item in rawList) {
          if (item is Map) {
            final s =
                double.tryParse(
                  (item['start'] ??
                          item['startSeconds'] ??
                          item['start_time'] ??
                          0)
                      .toString(),
                ) ??
                0;
            final e =
                double.tryParse(
                  (item['end'] ?? item['endSeconds'] ?? item['end_time'] ?? 0)
                      .toString(),
                ) ??
                0;
            if (s > 200 || e > 200) {
              isMs = true;
              break;
            }
          }
        }

        for (final item in rawList) {
          if (item is Map) {
            final w =
                item['word']?.toString() ?? item['text']?.toString() ?? '';
            final rawS =
                double.tryParse(
                  (item['start'] ??
                          item['startSeconds'] ??
                          item['start_time'] ??
                          0)
                      .toString(),
                ) ??
                0.0;
            final rawE =
                double.tryParse(
                  (item['end'] ?? item['endSeconds'] ?? item['end_time'] ?? 0)
                      .toString(),
                ) ??
                0.0;

            final s = isMs ? rawS / 1000.0 : rawS;
            final e = isMs ? rawE / 1000.0 : rawE;

            if (w.isNotEmpty) {
              parsedWords.add((word: w, start: s, end: e >= s ? e : s + 0.25));
            }
          }
        }
      }

      if (parsedWords.isNotEmpty && mounted) {
        setState(() {
          _buildLineTimings(parsedWords);
        });
      }
    } catch (e) {
      debugPrint('[PodcastTeleprompterText] Error parsing timestamps JSON: $e');
    }
  }

  String _cleanWord(String s) =>
      s.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();

  void _buildLineTimings(
    List<({String word, double start, double end})> allWords,
  ) {
    if (allWords.isEmpty || _alignedLines.isEmpty) {
      _lineTimings = const [];
      return;
    }

    // 1. Flatten all text words from all lines with their exact line and word indices
    final textWords =
        <({int lineIdx, int wordIdx, String rawWord, String clean})>[];
    for (int l = 0; l < _alignedLines.length; l++) {
      final lineTokens = _alignedLines[l].$1
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      for (int w = 0; w < lineTokens.length; w++) {
        textWords.add((
          lineIdx: l,
          wordIdx: w,
          rawWord: lineTokens[w],
          clean: _cleanWord(lineTokens[w]),
        ));
      }
    }

    if (textWords.isEmpty) {
      _lineTimings = const [];
      return;
    }

    // 2. Map every text word 1:1 to an audio timestamp interval
    final assignedTimings = List<({double start, double end})?>.filled(
      textWords.length,
      null,
    );

    int aCursor = 0;
    for (int t = 0; t < textWords.length; t++) {
      if (aCursor >= allWords.length) break;

      final target = textWords[t].clean;
      if (target.isEmpty) continue;

      final aCand = _cleanWord(allWords[aCursor].word);

      // A) Direct exact match
      if (aCand == target) {
        assignedTimings[t] = (
          start: allWords[aCursor].start,
          end: allWords[aCursor].end,
        );
        aCursor++;
        continue;
      }

      // B) Audio compound word (e.g. audio has "reallife", text has "real" followed by "life")
      if (t + 1 < textWords.length) {
        final combinedText = target + textWords[t + 1].clean;
        if (aCand == combinedText) {
          final s = allWords[aCursor].start;
          final e = allWords[aCursor].end;
          final mid = s + (e - s) * 0.5;
          assignedTimings[t] = (start: s, end: mid);
          assignedTimings[t + 1] = (start: mid, end: e);
          aCursor++;
          t++; // skip next since it is already assigned!
          continue;
        }
      }

      // C) Text compound word (e.g. text has "real-life", audio has "real" and "life")
      if (aCursor + 1 < allWords.length) {
        final combinedAudio = aCand + _cleanWord(allWords[aCursor + 1].word);
        if (target == combinedAudio) {
          assignedTimings[t] = (
            start: allWords[aCursor].start,
            end: allWords[aCursor + 1].end,
          );
          aCursor += 2;
          continue;
        }
      }

      // D) Forward search in audio (within 6 words window)
      int foundA = -1;
      for (int s = aCursor + 1; s < allWords.length && s <= aCursor + 6; s++) {
        if (_cleanWord(allWords[s].word) == target) {
          foundA = s;
          break;
        }
      }

      if (foundA != -1) {
        aCursor = foundA;
        assignedTimings[t] = (
          start: allWords[aCursor].start,
          end: allWords[aCursor].end,
        );
        aCursor++;
        continue;
      }

      // E) Check if audio skipped ahead (forward search in text)
      int foundT = -1;
      for (int st = t + 1; st < textWords.length && st <= t + 4; st++) {
        if (textWords[st].clean == aCand) {
          foundT = st;
          break;
        }
      }

      if (foundT != -1) {
        assignedTimings[t] = (
          start: allWords[aCursor].start,
          end: allWords[aCursor].end,
        );
        aCursor++;
        continue;
      }

      // F) Fallback: assign current audio cursor without skipping
      assignedTimings[t] = (
        start: allWords[aCursor].start,
        end: allWords[aCursor].end,
      );
      aCursor++;
    }

    // 3. Fill any unassigned gaps with smooth interpolation
    double lastEnd = 0.0;
    for (int t = 0; t < textWords.length; t++) {
      if (assignedTimings[t] == null) {
        double nextStart = lastEnd + 0.8;
        for (int k = t + 1; k < textWords.length; k++) {
          if (assignedTimings[k] != null) {
            nextStart = assignedTimings[k]!.start;
            break;
          }
        }
        final gap = (nextStart - lastEnd) / 2;
        assignedTimings[t] = (
          start: lastEnd,
          end: lastEnd + (gap > 0.2 ? gap : 0.3),
        );
      }
      lastEnd = assignedTimings[t]!.end;
    }

    // 4. Construct _LineTiming for each line with 100% 1:1 wordTimings matching
    final lineTimingsResult = <_LineTiming>[];
    int tokenIdx = 0;

    for (int l = 0; l < _alignedLines.length; l++) {
      final lineTokens = _alignedLines[l].$1
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();

      final currentLineWords = <({double start, double end})>[];
      for (int w = 0; w < lineTokens.length; w++) {
        if (tokenIdx < assignedTimings.length &&
            assignedTimings[tokenIdx] != null) {
          currentLineWords.add(assignedTimings[tokenIdx]!);
        } else {
          currentLineWords.add((start: lastEnd, end: lastEnd + 0.3));
        }
        tokenIdx++;
      }

      if (currentLineWords.isNotEmpty) {
        lineTimingsResult.add(
          _LineTiming(
            startSeconds: currentLineWords.first.start,
            endSeconds: currentLineWords.last.end,
            wordTimings: currentLineWords,
          ),
        );
      }
    }

    _lineTimings = lineTimingsResult;
  }

  void _autoScrollToActive({bool force = false}) {
    if (_alignedLines.isEmpty || _isAutoScrolling) return;
    if (_userInteractingWithScroll && !force) return;

    final activeIndex = _calculateActiveIndex();
    if (!force && activeIndex == _lastActiveIndex) return;
    _lastActiveIndex = activeIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final keyContext = _lineKeys[activeIndex]?.currentContext;
      if (keyContext != null) {
        _isAutoScrolling = true;
        Scrollable.ensureVisible(
          keyContext,
          alignment:
              0.5, // Center line precisely in the middle of the viewport!
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        ).then((_) {
          if (mounted) {
            _isAutoScrolling = false;
            if (_userScrolledAway) {
              setState(() => _userScrolledAway = false);
            }
          }
        });
      } else {
        // Line is offscreen in ListView.builder!
        // Scroll proportionally towards its estimated position so Flutter mounts it
        final totalLines = _alignedLines.length;
        if (totalLines > 0 && _scrollController.position.hasContentDimensions) {
          final maxScroll = _scrollController.position.maxScrollExtent;
          final targetOffset = ((activeIndex / totalLines) * maxScroll)
              .clamp(0.0, maxScroll);

          _isAutoScrolling = true;
          _scrollController
              .animateTo(
                targetOffset,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
              )
              .then((_) {
                if (!mounted) return;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  final contextAfterScroll =
                      _lineKeys[activeIndex]?.currentContext;
                  if (contextAfterScroll != null) {
                    Scrollable.ensureVisible(
                      contextAfterScroll,
                      alignment: 0.5,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOutCubic,
                    ).then((_) {
                      if (mounted) {
                        _isAutoScrolling = false;
                        if (_userScrolledAway) {
                          setState(() => _userScrolledAway = false);
                        }
                      }
                    });
                  } else {
                    _isAutoScrolling = false;
                  }
                });
              });
        }
      }
    });
  }

  int _calculateActiveIndex() {
    final totalLines = _alignedLines.length;
    if (totalLines == 0) return 0;

    // Use precise timestamps if available
    if (_lineTimings.isNotEmpty && _lineTimings.length == totalLines) {
      final cur = widget.currentSeconds;
      for (int i = 0; i < _lineTimings.length; i++) {
        final lt = _lineTimings[i];
        if (cur >= lt.startSeconds && cur <= lt.endSeconds) {
          return i;
        }
      }
      for (int i = 0; i < _lineTimings.length - 1; i++) {
        if (cur >= _lineTimings[i].endSeconds &&
            cur < _lineTimings[i + 1].startSeconds) {
          return i;
        }
      }
      if (cur >= _lineTimings.last.endSeconds) {
        return _lineTimings.length - 1;
      }
      return 0;
    }

    // Proportional fallback
    final totalDuration = widget.totalDurationSeconds > 0
        ? widget.totalDurationSeconds.toDouble()
        : 1.0;
    final progress = (widget.currentSeconds / totalDuration).clamp(0.0, 1.0);
    return (progress * totalLines).floor().clamp(0, totalLines - 1);
  }

  @override
  void dispose() {
    _autoResumeScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_alignedLines.isEmpty) {
      return Center(
        child: Text(
          'لا يوجد نص متاح لهذه الحلقة',
          style: TextStyle(
            color: widget.textColor.withValues(alpha: 0.6),
            fontFamily: 'IBM',
          ),
        ),
      );
    }

    final totalLines = _alignedLines.length;
    final totalDuration = widget.totalDurationSeconds > 0
        ? widget.totalDurationSeconds.toDouble()
        : 1.0;

    final activeIndex = _calculateActiveIndex();
    final viewportHeight = MediaQuery.sizeOf(context).height;

    final listView = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          if (notification.dragDetails != null) {
            _userInteractingWithScroll = true;
            _autoResumeScrollTimer?.cancel();
            if (!_userScrolledAway && mounted) {
              setState(() => _userScrolledAway = true);
            }
          }
        } else if (notification is ScrollEndNotification) {
          if (_userInteractingWithScroll) {
            _autoResumeScrollTimer?.cancel();
            if (widget.isPlaying) {
              _autoResumeScrollTimer =
                  Timer(const Duration(milliseconds: 2500), () {
                if (mounted && widget.isPlaying) {
                  _userInteractingWithScroll = false;
                  _autoScrollToActive(force: true);
                }
              });
            }
          }
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        // Top and bottom padding equal to ~35% of viewport height ensures every item can center perfectly
        padding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: viewportHeight * 0.35,
        ),
        itemCount: totalLines,
        itemBuilder: (context, index) {
          final pair = _alignedLines[index];
          final englishLine = pair.$1;
          final arabicLine = pair.$2;
          final isActive = index == activeIndex;
          final isPast = index < activeIndex;

          return RepaintBoundary(
            key: _lineKeys.putIfAbsent(index, () => GlobalKey()),
            child: _buildLineItem(
              index: index,
              englishLine: englishLine,
              arabicLine: arabicLine,
              isActive: isActive,
              isPast: isPast,
              totalDuration: totalDuration,
              totalLines: totalLines,
            ),
          );
        },
      ),
    );

    return Stack(
      children: [
        Positioned.fill(child: listView),
        if (_userScrolledAway && widget.isPlaying)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _userInteractingWithScroll = false;
                    _autoResumeScrollTimer?.cancel();
                    _autoScrollToActive(force: true);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.headphones_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'متابعة الجملة الحالية',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'IBM',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLineItem({
    required int index,
    required String englishLine,
    required String arabicLine,
    required bool isActive,
    required bool isPast,
    required double totalDuration,
    required int totalLines,
  }) {
    final words = englishLine
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    int activeWordIndex = -1;
    if (isActive && _lineTimings.isNotEmpty && index < _lineTimings.length) {
      final lt = _lineTimings[index];
      final cur = widget.currentSeconds;

      // 1. Direct match: currentSeconds is inside the word's time range
      for (int w = 0; w < lt.wordTimings.length; w++) {
        final wt = lt.wordTimings[w];
        if (cur >= wt.start && cur <= wt.end) {
          activeWordIndex = w;
          break;
        }
      }

      // 2. Pause between words: keep the word that just finished active
      if (activeWordIndex == -1) {
        for (int w = 0; w < lt.wordTimings.length - 1; w++) {
          if (cur > lt.wordTimings[w].end &&
              cur < lt.wordTimings[w + 1].start) {
            activeWordIndex = w;
            break;
          }
        }
      }

      // 3. Line boundaries fallback
      if (activeWordIndex == -1 && lt.wordTimings.isNotEmpty) {
        if (cur < lt.wordTimings.first.start) {
          activeWordIndex = 0;
        } else if (cur > lt.wordTimings.last.end) {
          activeWordIndex = lt.wordTimings.length - 1;
        }
      }
    } else if (isActive) {
      // Proportional fallback when timestamps are not loaded
      final lineDuration = totalDuration / totalLines;
      final lineStartSec = index * lineDuration;
      final lineProgress =
          ((widget.currentSeconds - lineStartSec) / lineDuration).clamp(
            0.0,
            1.0,
          );
      activeWordIndex = (lineProgress * words.length).floor().clamp(
        0,
        words.length - 1,
      );
    }

    return InkWell(
      onTap: () {
        double targetSec;
        if (_lineTimings.isNotEmpty && index < _lineTimings.length) {
          targetSec = _lineTimings[index].startSeconds;
        } else {
          final lineDuration = totalDuration / totalLines;
          targetSec = index * lineDuration;
        }
        widget.onLineTap?.call(targetSec);

        // Center on tap
        final keyContext = _lineKeys[index]?.currentContext;
        if (keyContext != null) {
          Scrollable.ensureVisible(
            keyContext,
            alignment: 0.5,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 24),
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 16 : 10,
          vertical: isActive ? 14 : 8,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? widget.highlightColor.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? widget.highlightColor.withValues(alpha: 0.40)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // English Line with Word-by-Word highlighting (strictly Left-to-Right)
            Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  textDirection: TextDirection.ltr,
                  spacing: 6,
                  runSpacing: 5,
                  children: List.generate(words.length, (wIdx) {
                    final rawWord = words[wIdx];
                    final normalized = normalizeNovelWord(rawWord);
                    final isCurrentWord = isActive && wIdx == activeWordIndex;

                    final dictWord = widget.episode.wordDictionary[normalized];
                    final hasDictionary = dictWord != null;

                    final wordKey = _wordKeys.putIfAbsent(
                      '${index}_$wIdx',
                      GlobalKey.new,
                    );

                    return GestureDetector(
                      key: wordKey,
                      onTap: () => widget.onWordTap(rawWord, dictWord, wordKey),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 140),
                        style: TextStyle(
                          fontFamily: 'IBM',
                          fontSize: isCurrentWord
                              ? widget.englishFontSize * 1.30
                              : (isActive
                                    ? widget.englishFontSize * 1.05
                                    : widget.englishFontSize),
                          fontWeight: isCurrentWord
                              ? FontWeight.w900
                              : (isActive ? FontWeight.w700 : FontWeight.w500),
                          color: isCurrentWord
                              ? (ThemeData.estimateBrightnessForColor(
                                          widget.pageColor,
                                        ) ==
                                        Brightness.dark
                                    ? const Color(0xFFFDE047)
                                    : const Color(0xFF4338CA))
                              : (isActive
                                    ? widget.textColor
                                    : widget.textColor.withValues(alpha: 0.45)),
                          decoration: hasDictionary
                              ? TextDecoration.underline
                              : TextDecoration.none,
                          decorationColor: hasDictionary
                              ? AppColors.primary.withValues(alpha: 0.6)
                              : null,
                          decorationStyle: TextDecorationStyle.dotted,
                        ),
                        child: Text(rawWord, textDirection: TextDirection.ltr),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // Arabic Translated Line (if toggle is on)
            if (widget.showTranslation && arabicLine.isNotEmpty) ...[
              const SizedBox(height: 10),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: isActive ? 1.0 : (isPast ? 0.60 : 0.40),
                child: Text(
                  arabicLine,
                  style: TextStyle(
                    fontFamily: 'IBM',
                    fontSize: widget.arabicFontSize,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? widget.textColor.withValues(alpha: 0.90)
                        : widget.textColor.withValues(alpha: 0.50),
                    height: 1.45,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
