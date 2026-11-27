import 'dart:math' as math;

typedef NovelWordAudioRange = ({double startSeconds, double endSeconds});

/// Word-level timing used by the reader to highlight and scroll to the
/// currently spoken word.
class WordTimestamp {
  const WordTimestamp({
    required this.word,
    required this.start,
    required this.end,
    required this.startSeconds,
    required this.endSeconds,
  });

  final String word;
  final int start;
  final int end;
  final double startSeconds;
  final double endSeconds;
}

/// Expands an aligned word to the safe boundaries between its neighbours.
/// The next word's start is the most reliable end boundary when an aligner
/// places the selected word's end inside its final phoneme.
NovelWordAudioRange calculateNovelWordAudioRange({
  required double currentStartSeconds,
  required double currentEndSeconds,
  required int wordLength,
  required double audioDurationSeconds,
  double? previousEndSeconds,
  double? nextStartSeconds,
}) {
  final start = previousEndSeconds == null
      ? math.max(0.0, currentStartSeconds - .10)
      : previousEndSeconds <= currentStartSeconds
      ? math.max(previousEndSeconds + .01, currentStartSeconds - .10)
      : math.max(0.0, currentStartSeconds - .08);
  final minDuration = (wordLength * .06).clamp(.14, .30);
  final estimatedDuration = (wordLength * .085).clamp(.30, 1.25);
  final fallbackEnd = math.min(
    audioDurationSeconds,
    math.max(currentEndSeconds + .14, currentStartSeconds + estimatedDuration),
  );
  final maxSafeEnd =
      nextStartSeconds != null && nextStartSeconds > currentStartSeconds
      ? nextStartSeconds - .01
      : null;
  final candidateEnd = maxSafeEnd ?? fallbackEnd;
  final clampedEnd = maxSafeEnd != null
      ? math.min(maxSafeEnd, math.max(start + minDuration, candidateEnd))
      : math.max(start + minDuration, candidateEnd);

  return (
    startSeconds: start,
    endSeconds: math.min(audioDurationSeconds, clampedEnd),
  );
}

class NovelAudioTimingData {
  const NovelAudioTimingData({
    required this.durationMs,
    required this.words,
    this.sourceAudioStartMs = 0,
    int? sourceAudioEndMs,
  }) : sourceAudioEndMs = sourceAudioEndMs ?? durationMs;

  final int durationMs;
  final List<NovelAudioWordTiming> words;
  final int sourceAudioStartMs;
  final int sourceAudioEndMs;
}

class NovelAudioWordTiming {
  const NovelAudioWordTiming({
    required this.word,
    required this.sourceStart,
    required this.sourceEnd,
    required this.startSeconds,
    required this.endSeconds,
  });

  final String word;
  final int sourceStart;
  final int sourceEnd;
  final double startSeconds;
  final double endSeconds;

  Map<String, Object> toMap() => {
    'word': word,
    'start': sourceStart,
    'end': sourceEnd,
    'startSeconds': startSeconds,
    'endSeconds': endSeconds,
  };
}

/// Reads the app format or `[{"text":"Mia","start":130,"end":363}]`.
/// A raw list may describe one chapter or the full novel.
NovelAudioTimingData parseNovelAudioTimings(
  Object? value, {
  required String chapterText,
  bool allowChapterInsideFullNovel = true,
}) {
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    final rawWords = map['timestamps'];
    if (rawWords is! List || rawWords.isEmpty) {
      throw const FormatException('timestamps must be a non-empty JSON list.');
    }
    final first = rawWords.first;
    if (first is Map && first.containsKey('startSeconds')) {
      return _parseCanonicalTimings(map, rawWords, chapterText);
    }
    return _alignMillisecondTimings(
      rawWords,
      chapterText: chapterText,
      durationHintMs: (map['durationMs'] as num?)?.toInt(),
      allowChapterInsideFullNovel: allowChapterInsideFullNovel,
    );
  }
  if (value is List) {
    return _alignMillisecondTimings(
      value,
      chapterText: chapterText,
      allowChapterInsideFullNovel: allowChapterInsideFullNovel,
    );
  }
  throw const FormatException('Unsupported novel audio timestamp JSON.');
}

NovelAudioTimingData _parseCanonicalTimings(
  Map<String, dynamic> metadata,
  List<dynamic> rawWords,
  String chapterText,
) {
  final words = <NovelAudioWordTiming>[];
  for (var index = 0; index < rawWords.length; index++) {
    final raw = rawWords[index];
    if (raw is! Map) {
      throw FormatException('Invalid timestamp at index $index.');
    }
    final item = Map<String, dynamic>.from(raw);
    final word = item['word']?.toString() ?? '';
    final sourceStart = (item['start'] as num?)?.toInt();
    final sourceEnd = (item['end'] as num?)?.toInt();
    final startSeconds = (item['startSeconds'] as num?)?.toDouble();
    final endSeconds = (item['endSeconds'] as num?)?.toDouble();
    if (word.isEmpty ||
        sourceStart == null ||
        sourceEnd == null ||
        sourceStart < 0 ||
        sourceEnd <= sourceStart ||
        sourceEnd > chapterText.length ||
        startSeconds == null ||
        endSeconds == null ||
        startSeconds < 0 ||
        endSeconds <= startSeconds) {
      throw FormatException('Invalid timestamp at index $index.');
    }
    if (_normalizeWord(chapterText.substring(sourceStart, sourceEnd)) !=
        _normalizeWord(word)) {
      throw FormatException(
        'Timestamp word "$word" at index $index does not match the chapter text.',
      );
    }
    words.add(
      NovelAudioWordTiming(
        word: word,
        sourceStart: sourceStart,
        sourceEnd: sourceEnd,
        startSeconds: startSeconds,
        endSeconds: endSeconds,
      ),
    );
  }
  final durationMs =
      (metadata['durationMs'] as num?)?.toInt() ??
      (words.last.endSeconds * 1000).ceil();
  if (durationMs <= 0) {
    throw const FormatException('durationMs must be positive.');
  }
  return NovelAudioTimingData(durationMs: durationMs, words: words);
}

NovelAudioTimingData _alignMillisecondTimings(
  List<dynamic> rawWords, {
  required String chapterText,
  int? durationHintMs,
  required bool allowChapterInsideFullNovel,
}) {
  if (rawWords.isEmpty) {
    throw const FormatException('timestamps must not be empty.');
  }
  final textWords = _wordPattern.allMatches(chapterText).toList();
  if (textWords.isEmpty) {
    throw const FormatException('Chapter text must contain words.');
  }

  final rawItems = <Map<String, dynamic>>[];
  final rawNormalized = <String>[];
  for (var index = 0; index < rawWords.length; index++) {
    final raw = rawWords[index];
    if (raw is! Map) {
      throw FormatException('Invalid timestamp at index $index.');
    }
    final item = Map<String, dynamic>.from(raw);
    rawItems.add(item);
    rawNormalized.add(
      _normalizeWord((item['text'] ?? item['word'])?.toString() ?? ''),
    );
  }
  final textNormalized = [
    for (final word in textWords) _normalizeWord(word.group(0)!),
  ];

  final rawStartIndex = rawWords.length == textWords.length
      ? 0
      : allowChapterInsideFullNovel
      ? _findChapterStartIndex(rawNormalized, textNormalized)
      : -1;

  if (rawStartIndex < 0) {
    throw const FormatException(
      'The chapter words were not found as one continuous section in the audio timestamps.',
    );
  }

  final sourceAudioStartMs = rawWords.length == textWords.length
      ? 0
      : (rawItems[rawStartIndex]['start'] as num?)?.toInt();
  if (sourceAudioStartMs == null || sourceAudioStartMs < 0) {
    throw FormatException('Invalid timestamp at index $rawStartIndex.');
  }

  var rawCursor = rawStartIndex;
  var previousStartMs = sourceAudioStartMs;
  var lastEndMs = sourceAudioStartMs;
  final words = <NovelAudioWordTiming>[];

  for (var index = 0; index < textWords.length; index++) {
    final match = textWords[index];
    final textWord = match.group(0)!;
    final normText = _normalizeWord(textWord);

    // Look ahead in rawItems within a small window (0 to 3 items) to find best match
    int? matchedRawIndex;
    for (
      var lookahead = 0;
      lookahead <= 3 && (rawCursor + lookahead) < rawItems.length;
      lookahead++
    ) {
      final candRaw = rawItems[rawCursor + lookahead];
      final spoken = (candRaw['text'] ?? candRaw['word'] ?? '').toString();
      if (_wordsMatch(normText, spoken)) {
        matchedRawIndex = rawCursor + lookahead;
        break;
      }
    }

    // Also check if text has a compound number like 'two hundred' matching '200'
    if (matchedRawIndex == null &&
        index + 1 < textWords.length &&
        rawCursor < rawItems.length) {
      final candRaw = rawItems[rawCursor];
      final spoken = _normalizeWord(
        (candRaw['text'] ?? candRaw['word'] ?? '').toString(),
      );
      final nextTextWord = _normalizeWord(textWords[index + 1].group(0)!);
      if (_isCompoundNumberMatch(normText, nextTextWord, spoken)) {
        matchedRawIndex = rawCursor;
      }
    }

    int startMs;
    int endMs;

    if (matchedRawIndex != null) {
      final item = rawItems[matchedRawIndex];
      startMs = (item['start'] as num?)?.toInt() ?? lastEndMs;
      endMs = (item['end'] as num?)?.toInt() ?? (startMs + 300);
      rawCursor = matchedRawIndex + 1;
    } else {
      // Interpolate / carry forward gracefully if word was omitted or slightly off
      if (rawCursor < rawItems.length) {
        final item = rawItems[rawCursor];
        startMs = (item['start'] as num?)?.toInt() ?? lastEndMs;
        endMs = (item['end'] as num?)?.toInt() ?? (startMs + 250);
        rawCursor++;
      } else {
        startMs = lastEndMs + 40;
        endMs = startMs + 250;
      }
    }

    if (startMs < previousStartMs) {
      startMs = previousStartMs;
    }
    if (endMs <= startMs) {
      endMs = startMs + 200;
    }

    words.add(
      NovelAudioWordTiming(
        word: match.group(0)!,
        sourceStart: match.start,
        sourceEnd: match.end,
        startSeconds: (startMs - sourceAudioStartMs) / 1000,
        endSeconds: (endMs - sourceAudioStartMs) / 1000,
      ),
    );

    previousStartMs = startMs;
    if (endMs > lastEndMs) lastEndMs = endMs;
  }

  final sourceAudioEndMs = rawWords.length == textWords.length
      ? (durationHintMs == null || durationHintMs < lastEndMs
            ? lastEndMs
            : durationHintMs)
      : lastEndMs;

  return NovelAudioTimingData(
    durationMs: sourceAudioEndMs - sourceAudioStartMs,
    words: words,
    sourceAudioStartMs: sourceAudioStartMs,
    sourceAudioEndMs: sourceAudioEndMs,
  );
}

int _findChapterStartIndex(
  List<String> rawNormalized,
  List<String> textNormalized,
) {
  if (textNormalized.isEmpty || rawNormalized.isEmpty) return -1;
  if (textNormalized.length > rawNormalized.length + 10) return -1;

  final anchorLen = textNormalized.length < 8 ? textNormalized.length : 8;
  final anchorWords = textNormalized.sublist(0, anchorLen);

  int bestStart = -1;
  int maxScore = 0;

  for (var start = 0; start <= rawNormalized.length - anchorLen; start++) {
    var score = 0;
    for (var i = 0; i < anchorLen; i++) {
      if (_wordsMatch(rawNormalized[start + i], anchorWords[i])) {
        score++;
      }
    }
    if (score >= (anchorLen * 0.6).ceil()) {
      final verifyLen = textNormalized.length < 35 ? textNormalized.length : 35;
      final maxVerify = start + verifyLen <= rawNormalized.length
          ? verifyLen
          : rawNormalized.length - start;
      var verifyScore = 0;
      for (var i = 0; i < maxVerify; i++) {
        if (_wordsMatch(rawNormalized[start + i], textNormalized[i])) {
          verifyScore++;
        }
      }
      if (verifyScore > maxScore) {
        maxScore = verifyScore;
        bestStart = start;
      }
    }
  }

  if (bestStart >= 0 &&
      maxScore >= (math.min(textNormalized.length, 35) * 0.45).ceil()) {
    return bestStart;
  }

  // Fallback: sliding window across the entire list
  for (
    var start = 0;
    start <= rawNormalized.length - textNormalized.length + 5;
    start++
  ) {
    final testLen = math.min(
      textNormalized.length,
      rawNormalized.length - start,
    );
    var matches = 0;
    for (var i = 0; i < testLen; i++) {
      if (_wordsMatch(rawNormalized[start + i], textNormalized[i])) {
        matches++;
      }
    }
    if (matches > maxScore) {
      maxScore = matches;
      bestStart = start;
    }
  }

  if (bestStart >= 0 && maxScore >= (textNormalized.length * 0.4).ceil()) {
    return bestStart;
  }

  return -1;
}

const Map<String, int> _numberWordValues = {
  'zero': 0,
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'eleven': 11,
  'twelve': 12,
  'thirteen': 13,
  'fourteen': 14,
  'fifteen': 15,
  'sixteen': 16,
  'seventeen': 17,
  'eighteen': 18,
  'nineteen': 19,
  'twenty': 20,
  'thirty': 30,
  'forty': 40,
  'fifty': 50,
  'sixty': 60,
  'seventy': 70,
  'eighty': 80,
  'ninety': 90,
  'hundred': 100,
  'thousand': 1000,
  'million': 1000000,
};

bool _wordsMatch(String a, String b) {
  final na = _normalizeWord(a);
  final nb = _normalizeWord(b);
  if (na == nb) return true;
  if (na.isEmpty || nb.isEmpty) return false;

  final numA = int.tryParse(na);
  final numB = int.tryParse(nb);
  if (numA != null && _numberWordValues[nb] == numA) return true;
  if (numB != null && _numberWordValues[na] == numB) return true;

  // Common phonetic / transcription name and punctuation variations
  if ((na == 'youssef' && nb == 'yusuf') ||
      (na == 'yusuf' && nb == 'youssef')) {
    return true;
  }
  if ((na == 'alnour' && nb == 'al-nour') ||
      (na == 'al-nour' && nb == 'alnour')) {
    return true;
  }

  // Levenshtein distance for words of length >= 5
  if (na.length >= 5 && nb.length >= 5 && (na.length - nb.length).abs() <= 2) {
    if (_levenshteinDistance(na, nb) <= 1) return true;
  }

  return false;
}

bool _isCompoundNumberMatch(String word1, String word2, String targetDigit) {
  final v1 = _numberWordValues[word1];
  final v2 = _numberWordValues[word2];
  if (v1 != null && v2 != null) {
    final combined = v1 * v2;
    return combined.toString() == targetDigit;
  }
  return false;
}

int _levenshteinDistance(String s, String t) {
  if (s == t) return 0;
  if (s.isEmpty) return t.length;
  if (t.isEmpty) return s.length;
  List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
  List<int> v1 = List<int>.filled(t.length + 1, 0);
  for (int i = 0; i < s.length; i++) {
    v1[0] = i + 1;
    for (int j = 0; j < t.length; j++) {
      int cost = (s[i] == t[j]) ? 0 : 1;
      v1[j + 1] = math.min(v1[j] + 1, math.min(v0[j + 1] + 1, v0[j] + cost));
    }
    for (int j = 0; j <= t.length; j++) {
      v0[j] = v1[j];
    }
  }
  return v1[t.length];
}

final _wordPattern = RegExp(r"[A-Za-z0-9]+(?:['’-][A-Za-z0-9]+)*");

String _normalizeWord(String value) => value
    .toLowerCase()
    .replaceAll('’', "'")
    .replaceAll(RegExp(r"[^a-z0-9']"), '');
