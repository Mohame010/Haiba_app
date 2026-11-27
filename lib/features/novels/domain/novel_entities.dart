import 'novel_word_normalizer.dart';

class Novel {
  const Novel({
    required this.id,
    required this.title,
    required this.description,
    required this.level,
    required this.coverUrl,
    required this.isFree,
    required this.chapters,
    this.wordDictionary = const {},
    this.videoUrl,
    this.videoSegments = const [],
  });

  final String id;
  final String title;
  final String description;
  final String level;
  final String? coverUrl;
  final bool isFree;
  final List<NovelChapter> chapters;
  final Map<String, NovelWord> wordDictionary;
  final String? videoUrl;
  final List<NovelVideoSegment> videoSegments;

  factory Novel.fromMap(Map<String, dynamic> map) {
    final dictionary = <String, NovelWord>{};
    final rawDictionary = map['word_dictionary'];
    if (rawDictionary is Map) {
      for (final entry in rawDictionary.entries) {
        if (entry.value is! Map) continue;
        final word = NovelWord.fromMap(
          Map<String, dynamic>.from(entry.value as Map),
          entry.key.toString(),
        );
        final normalized = normalizeNovelWord(entry.key.toString());
        if (normalized.isNotEmpty) dictionary[normalized] = word;
      }
    }
    return Novel(
      id: map['id'].toString(),
      title: map['title']?.toString() ?? 'رواية بدون عنوان',
      description: map['description']?.toString() ?? '',
      level: map['level']?.toString() ?? 'beginner',
      coverUrl: map['cover_url']?.toString(),
      isFree: map['is_free'] == true,
      wordDictionary: dictionary,
      videoUrl: map['video_url']?.toString(),
      videoSegments: NovelVideoSegment.parseList(
        map['video_segments'] ?? map['video_url'],
        defaultVideoUrl: map['video_url']?.toString(),
      ),
      chapters:
          ((map['novel_chapters'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (item) => NovelChapter.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList()
            ..sort((first, second) => first.order.compareTo(second.order))),
    );
  }
}

class NovelChapter {
  const NovelChapter({
    required this.id,
    required this.title,
    required this.order,
    required this.text,
    required this.translation,
    required this.audioUrl,
    this.audioTimestampsUrl,
    this.audioRevision = 1,
    this.recordedAudioConfigured = false,
    this.recordedAudioError,
    this.videoUrl,
    this.videoSegments = const [],
  });

  final String id;
  final String title;
  final int order;
  final String text;
  final String translation;
  final String? audioUrl;
  final String? audioTimestampsUrl;
  final int audioRevision;
  final bool recordedAudioConfigured;
  final String? recordedAudioError;
  final String? videoUrl;
  final List<NovelVideoSegment> videoSegments;

  /// Whether this chapter has pre-generated audio + timestamps available
  /// on the server, ready for instant playback.
  bool get hasPreGeneratedAudio =>
      audioUrl != null &&
      audioUrl!.isNotEmpty &&
      audioTimestampsUrl != null &&
      audioTimestampsUrl!.isNotEmpty;

  bool get hasRecordedAudioConfigured =>
      recordedAudioConfigured || hasPreGeneratedAudio;

  factory NovelChapter.fromMap(Map<String, dynamic> map) => NovelChapter(
    id: map['id'].toString(),
    title: map['title']?.toString() ?? 'Chapter',
    order: (map['sort_order'] as num?)?.toInt() ?? 0,
    text: map['text']?.toString() ?? '',
    translation: map['translation']?.toString() ?? '',
    audioUrl: map['audio_url']?.toString(),
    audioTimestampsUrl: map['audio_timestamps_url']?.toString(),
    audioRevision: (map['audio_revision'] as num?)?.toInt() ?? 1,
    recordedAudioConfigured:
        map['recorded_audio_configured'] == true ||
        ((map['audio_storage_path']?.toString().isNotEmpty ?? false) &&
            (map['audio_timestamps_storage_path']?.toString().isNotEmpty ??
                false)),
    recordedAudioError: map['recorded_audio_error']?.toString(),
    videoUrl: map['video_url']?.toString(),
    videoSegments: NovelVideoSegment.parseList(
      map['video_segments'] ?? map['video_url'],
      defaultVideoUrl: map['video_url']?.toString(),
    ),
  );
}

class NovelVideoSegment {
  const NovelVideoSegment({
    required this.startSeconds,
    required this.endSeconds,
    required this.videoUrl,
    this.title,
  });

  final double startSeconds;
  final double endSeconds;
  final String videoUrl;
  final String? title;

  bool isActiveAt(double seconds) {
    if (endSeconds <= startSeconds) return true;
    return seconds >= startSeconds && seconds < endSeconds;
  }

  factory NovelVideoSegment.fromMap(Map<String, dynamic> map) {
    final start =
        (map['start_seconds'] ?? map['startSeconds'] ?? map['start'] ?? 0.0);
    final end = (map['end_seconds'] ?? map['endSeconds'] ?? map['end'] ?? 0.0);
    return NovelVideoSegment(
      startSeconds: start is num
          ? start.toDouble()
          : double.tryParse(start.toString()) ?? 0.0,
      endSeconds: end is num
          ? end.toDouble()
          : double.tryParse(end.toString()) ?? 0.0,
      videoUrl: (map['video_url'] ?? map['videoUrl'] ?? map['url'] ?? '')
          .toString(),
      title: map['title']?.toString(),
    );
  }

  static List<NovelVideoSegment> parseList(
    dynamic raw, {
    String? defaultVideoUrl,
  }) {
    final segments = <NovelVideoSegment>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          segments.add(
            NovelVideoSegment.fromMap(Map<String, dynamic>.from(item)),
          );
        } else if (item is String && item.trim().isNotEmpty) {
          segments.add(
            NovelVideoSegment(
              startSeconds: 0,
              endSeconds: 0,
              videoUrl: item.trim(),
            ),
          );
        }
      }
    } else if (raw is Map) {
      segments.add(NovelVideoSegment.fromMap(Map<String, dynamic>.from(raw)));
    } else if (raw is String && raw.trim().isNotEmpty) {
      segments.add(
        NovelVideoSegment(startSeconds: 0, endSeconds: 0, videoUrl: raw.trim()),
      );
    }

    if (segments.isEmpty &&
        defaultVideoUrl != null &&
        defaultVideoUrl.trim().isNotEmpty) {
      segments.add(
        NovelVideoSegment(
          startSeconds: 0,
          endSeconds: 0,
          videoUrl: defaultVideoUrl.trim(),
        ),
      );
    }
    return segments;
  }
}

class NovelWord {
  const NovelWord({
    required this.word,
    required this.arabicMeaning,
    required this.contextMeaning,
    required this.transcription,
    this.novelTitle,
    this.chapterNumber,
    this.audioUrl,
    this.partOfSpeech,
  });

  final String word;
  final String arabicMeaning;
  final String contextMeaning;
  final String transcription;
  final String? novelTitle;
  final int? chapterNumber;
  final String? audioUrl;
  final String? partOfSpeech;

  factory NovelWord.fromMap(Map<String, dynamic> map, String fallback) =>
      NovelWord(
        word: map['word']?.toString() ?? fallback,
        arabicMeaning:
            map['arabic_meaning']?.toString() ?? 'اضغط لمعرفة المعنى',
        contextMeaning: map['context_meaning']?.toString() ?? '',
        transcription: map['transcription']?.toString() ?? '',
        novelTitle: map['novel_title']?.toString(),
        chapterNumber: (map['chapter_number'] as num?)?.toInt(),
        audioUrl: map['audio_url']?.toString(),
        partOfSpeech: map['part_of_speech']?.toString(),
      );

  Map<String, dynamic> toMap() => {
    'word': word,
    'arabic_meaning': arabicMeaning,
    'context_meaning': contextMeaning,
    'transcription': transcription,
    if (novelTitle != null) 'novel_title': novelTitle,
    if (chapterNumber != null) 'chapter_number': chapterNumber,
    if (audioUrl != null) 'audio_url': audioUrl,
    if (partOfSpeech != null) 'part_of_speech': partOfSpeech,
  };
}

class NovelSubscriptionPlan {
  const NovelSubscriptionPlan({
    required this.id,
    required this.name,
    required this.durationDays,
    required this.price,
    required this.currency,
    this.listeningLimitSeconds,
    this.listeningPeriod = 'unlimited',
    this.openNovelsLimit,
    this.openAllNovels = false,
    this.openPoetry = true,
    this.openPodcasts = true,
    this.isDiscount = false,
    this.oldPrice,
    this.description,
  });

  final String id;
  final String name;
  final int durationDays;
  final double price;
  final String currency;
  final int? listeningLimitSeconds;
  final String listeningPeriod;
  final int? openNovelsLimit;
  final bool openAllNovels;
  final bool openPoetry;
  final bool openPodcasts;
  final bool isDiscount;
  final double? oldPrice;
  final String? description;

  factory NovelSubscriptionPlan.fromMap(Map<String, dynamic> map) =>
      NovelSubscriptionPlan(
        id: map['id'].toString(),
        name: map['name']?.toString() ?? 'باقة روايات',
        durationDays: (map['duration_days'] as num?)?.toInt() ?? 30,
        price:
            (map['new_price'] as num?)?.toDouble() ??
            (map['price'] as num?)?.toDouble() ??
            0,
        currency: map['currency']?.toString() ?? 'EGP',
        listeningLimitSeconds: (map['listening_limit_seconds'] as num?)
            ?.toInt(),
        listeningPeriod: map['listening_period']?.toString() ?? 'unlimited',
        openNovelsLimit: (map['open_novels_limit'] as num?)?.toInt(),
        openAllNovels: map['open_all_novels'] == true,
        openPoetry: map['open_poetry'] != false,
        openPodcasts: map['open_podcasts'] != false,
        isDiscount: map['is_discount'] == true,
        oldPrice: (map['old_price'] as num?)?.toDouble(),
        description: map['description']?.toString(),
      );
}
