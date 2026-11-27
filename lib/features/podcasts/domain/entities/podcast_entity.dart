import 'dart:convert';
import '../../../novels/domain/novel_entities.dart';
import '../../../novels/domain/novel_word_normalizer.dart';

class PodcastVideoSegment {
  const PodcastVideoSegment({
    required this.id,
    required this.videoUrl,
    required this.startSeconds,
    required this.endSeconds,
    this.title,
    this.thumbnailUrl,
  });

  final String id;
  final String videoUrl;
  final double startSeconds;
  final double endSeconds;
  final String? title;
  final String? thumbnailUrl;

  bool isActiveAt(double currentSeconds) {
    if (endSeconds <= startSeconds) {
      return true;
    }
    return currentSeconds >= startSeconds && currentSeconds <= endSeconds;
  }

  factory PodcastVideoSegment.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic val, [double fallback = 0.0]) {
      if (val == null) return fallback;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? fallback;
    }

    final start = parseDouble(map['start_seconds'] ?? map['startSeconds'] ?? map['start'], 0.0);
    var end = parseDouble(map['end_seconds'] ?? map['endSeconds'] ?? map['end'], 0.0);
    if (end <= start) {
      end = 999999.0;
    }

    return PodcastVideoSegment(
      id: map['id']?.toString() ?? '',
      videoUrl: (map['video_url'] ?? map['videoUrl'] ?? map['url'])?.toString() ?? '',
      startSeconds: start,
      endSeconds: end,
      title: map['title']?.toString(),
      thumbnailUrl: (map['thumbnail_url'] ?? map['thumbnailUrl'])?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'video_url': videoUrl,
    'start_seconds': startSeconds,
    'end_seconds': endSeconds,
    'title': title,
    'thumbnail_url': thumbnailUrl,
  };
}

class PodcastEpisode {
  const PodcastEpisode({
    required this.id,
    required this.title,
    required this.description,
    required this.host,
    required this.audioUrl,
    required this.durationSeconds,
    required this.text,
    required this.translation,
    this.coverUrl,
    this.audioTimestampsUrl,
    this.audioTimestampsData,
    this.videoSegments = const [],
    this.wordDictionary = const {},
    this.category = 'تطوير الذات واللغة',
    this.publishedAt,
    this.isFeatured = false,
  });

  final String id;
  final String title;
  final String description;
  final String host;
  final String audioUrl;
  final int durationSeconds;
  final String text;
  final String translation;
  final String? coverUrl;
  final String? audioTimestampsUrl;
  final dynamic audioTimestampsData;
  final List<PodcastVideoSegment> videoSegments;
  final Map<String, NovelWord> wordDictionary;
  final String category;
  final DateTime? publishedAt;
  final bool isFeatured;

  String get durationFormatted {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  factory PodcastEpisode.fromMap(Map<String, dynamic> map) {
    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? 0;
    }

    final duration = parseInt(map['duration_seconds'] ?? map['durationSeconds']);

    final dictionary = <String, NovelWord>{};
    final rawDict = map['word_dictionary'] ?? map['wordDictionary'];

    void parseDictionaryMap(Map entries) {
      for (final entry in entries.entries) {
        if (entry.value is! Map) continue;
        final rawVal = Map<String, dynamic>.from(entry.value as Map);
        final normalizedMap = <String, dynamic>{
          'word': rawVal['word']?.toString() ??
              rawVal['name']?.toString() ??
              entry.key.toString(),
          'arabic_meaning': rawVal['arabic_meaning'] ??
              rawVal['arabicMeaning'] ??
              rawVal['meaning'] ??
              'اضغط لمعرفة المعنى',
          'context_meaning': rawVal['context_meaning'] ??
              rawVal['contextMeaning'] ??
              '',
          'transcription': rawVal['transcription'] ??
              rawVal['phonetic'] ??
              '',
          'novel_title': rawVal['novel_title'] ?? rawVal['novelTitle'],
          'chapter_number': rawVal['chapter_number'] ?? rawVal['chapterNumber'],
          'audio_url': rawVal['audio_url'] ?? rawVal['audioUrl'],
          'part_of_speech': rawVal['part_of_speech'] ?? rawVal['partOfSpeech'],
        };
        final word = NovelWord.fromMap(
          normalizedMap,
          entry.key.toString(),
        );
        final normalized = normalizeNovelWord(entry.key.toString());
        if (normalized.isNotEmpty) dictionary[normalized] = word;
      }
    }

    if (rawDict is Map) {
      parseDictionaryMap(rawDict);
    } else if (rawDict is String && rawDict.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDict);
        if (decoded is Map) {
          parseDictionaryMap(decoded);
        }
      } catch (_) {}
    }

    final segments = <PodcastVideoSegment>[];
    final rawSegments = map['video_segments'] ?? map['videoSegments'];
    final singleVideoUrl = (map['video_url'] ?? map['videoUrl'])?.toString();

    void addSegmentFromMap(Map item, int idx) {
      final segMap = Map<String, dynamic>.from(item);
      final vUrl = (segMap['video_url'] ?? segMap['videoUrl'] ?? segMap['url'])?.toString() ?? '';
      if (vUrl.trim().isEmpty) return;

      double parseD(dynamic v, double fallback) {
        if (v == null) return fallback;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString()) ?? fallback;
      }

      final startSec = parseD(segMap['start_seconds'] ?? segMap['startSeconds'] ?? segMap['start'], 0.0);
      var endSec = parseD(segMap['end_seconds'] ?? segMap['endSeconds'] ?? segMap['end'], 0.0);
      if (endSec <= startSec) {
        endSec = duration > 0 ? duration.toDouble() : 999999.0;
      }

      segments.add(
        PodcastVideoSegment(
          id: segMap['id']?.toString() ?? 'seg-$idx',
          videoUrl: vUrl.trim(),
          startSeconds: startSec,
          endSeconds: endSec,
          title: segMap['title']?.toString(),
          thumbnailUrl: (segMap['thumbnail_url'] ?? segMap['thumbnailUrl'])?.toString(),
        ),
      );
    }

    if (rawSegments is List) {
      for (int i = 0; i < rawSegments.length; i++) {
        final item = rawSegments[i];
        if (item is Map) {
          addSegmentFromMap(item, i);
        } else if (item is String && item.trim().startsWith('http')) {
          segments.add(
            PodcastVideoSegment(
              id: 'seg-$i',
              videoUrl: item.trim(),
              startSeconds: 0,
              endSeconds: duration > 0 ? duration.toDouble() : 999999.0,
            ),
          );
        }
      }
    } else if (rawSegments is Map) {
      addSegmentFromMap(rawSegments, 0);
    } else if (rawSegments is String && rawSegments.trim().isNotEmpty) {
      final trimmed = rawSegments.trim();
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        segments.add(
          PodcastVideoSegment(
            id: 'seg-0',
            videoUrl: trimmed,
            startSeconds: 0,
            endSeconds: duration > 0 ? duration.toDouble() : 999999.0,
          ),
        );
      } else {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            for (int i = 0; i < decoded.length; i++) {
              if (decoded[i] is Map) addSegmentFromMap(decoded[i] as Map, i);
            }
          } else if (decoded is Map) {
            addSegmentFromMap(decoded, 0);
          }
        } catch (_) {}
      }
    }

    // Check singleVideoUrl fallback
    if (segments.isEmpty && singleVideoUrl != null && singleVideoUrl.trim().isNotEmpty) {
      segments.add(
        PodcastVideoSegment(
          id: 'seg-single',
          videoUrl: singleVideoUrl.trim(),
          startSeconds: 0,
          endSeconds: duration > 0 ? duration.toDouble() : 999999.0,
          title: 'فيديو الحلقة',
        ),
      );
    }

    DateTime? publishedDate;
    final dateRaw = map['created_at'] ?? map['createdAt'] ?? map['published_at'];
    if (dateRaw != null) {
      publishedDate = DateTime.tryParse(dateRaw.toString());
    }

    return PodcastEpisode(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'حلقة بدون عنوان',
      description: map['description']?.toString() ?? '',
      host: map['host']?.toString() ?? 'بودكاست Q360',
      audioUrl: (map['audio_url'] ?? map['audioUrl'])?.toString() ?? '',
      durationSeconds: duration,
      text: map['text']?.toString() ?? '',
      translation: map['translation']?.toString() ?? '',
      coverUrl: (map['cover_url'] ?? map['coverUrl'])?.toString(),
      audioTimestampsUrl: (map['audio_timestamps_url'] ?? map['audioTimestampsUrl'])?.toString(),
      audioTimestampsData: map['audio_timestamps_data'] ?? map['audioTimestampsData'],
      videoSegments: segments,
      wordDictionary: dictionary,
      category: map['category']?.toString() ?? 'تعليمي',
      publishedAt: publishedDate,
      isFeatured: map['is_featured'] == true || map['isFeatured'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'host': host,
    'audio_url': audioUrl,
    'duration_seconds': durationSeconds,
    'text': text,
    'translation': translation,
    'cover_url': coverUrl,
    'audio_timestamps_url': audioTimestampsUrl,
    'category': category,
    'is_featured': isFeatured,
    'video_segments': videoSegments.map((s) => s.toMap()).toList(),
    'word_dictionary': wordDictionary.map((k, v) => MapEntry(k, v.toMap())),
  };
}
