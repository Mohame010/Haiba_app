import 'package:hive_ce_flutter/hive_flutter.dart';

class NovelReaderPreferences {
  const NovelReaderPreferences({
    required this.fontSize,
    required this.pageColor,
    required this.textColor,
    this.backgroundPath,
    this.chapterPositions = const <String, int>{},
    this.chapterSyncOffsets = const <String, int>{},
    this.mixerOffsetX,
    this.mixerOffsetY,
    this.highlightColor = 0xFFFFE28A,
    this.englishFontSize = 19,
    this.arabicFontSize = 18,
    this.playbackRate = 1,
    this.wordPlaybackRate = 1,
    this.readerVoiceId = 'lucas',
  });

  final double fontSize;
  final int pageColor;
  final int textColor;
  final String? backgroundPath;
  final Map<String, int> chapterPositions;
  final Map<String, int> chapterSyncOffsets;
  final double? mixerOffsetX;
  final double? mixerOffsetY;
  final int highlightColor;
  final double englishFontSize;
  final double arabicFontSize;
  final double playbackRate;
  final double wordPlaybackRate;
  final String readerVoiceId;

  factory NovelReaderPreferences.fromMap(Map map) => NovelReaderPreferences(
    fontSize: (map['fontSize'] as num?)?.toDouble() ?? 19,
    pageColor: (map['pageColor'] as num?)?.toInt() ?? 0xffFFFDF7,
    textColor: (map['textColor'] as num?)?.toInt() ?? 0xff17202A,
    backgroundPath: map['backgroundPath'] as String?,
    chapterPositions: {
      for (final entry in (map['chapterPositions'] as Map? ?? const {}).entries)
        entry.key.toString(): (entry.value as num?)?.toInt() ?? 0,
    },
    chapterSyncOffsets: {
      for (final entry
          in (map['chapterSyncOffsets'] as Map? ?? const {}).entries)
        entry.key.toString(): (entry.value as num?)?.toInt() ?? 0,
    },
    mixerOffsetX: (map['mixerOffsetX'] as num?)?.toDouble(),
    mixerOffsetY: (map['mixerOffsetY'] as num?)?.toDouble(),
    highlightColor: (map['highlightColor'] as num?)?.toInt() ?? 0xFFFFE28A,
    englishFontSize:
        (map['englishFontSize'] as num?)?.toDouble() ??
        (map['fontSize'] as num?)?.toDouble() ??
        19,
    arabicFontSize:
        (map['arabicFontSize'] as num?)?.toDouble() ??
        (map['fontSize'] as num?)?.toDouble() ??
        18,
    playbackRate: (map['playbackRate'] as num?)?.toDouble() ?? 1,
    wordPlaybackRate: (map['wordPlaybackRate'] as num?)?.toDouble() ?? 1,
    readerVoiceId: map['readerVoiceId']?.toString() ?? 'lucas',
  );

  Map<String, Object?> toMap() => {
    'fontSize': fontSize,
    'pageColor': pageColor,
    'textColor': textColor,
    'backgroundPath': backgroundPath,
    'chapterPositions': chapterPositions,
    'chapterSyncOffsets': chapterSyncOffsets,
    'mixerOffsetX': mixerOffsetX,
    'mixerOffsetY': mixerOffsetY,
    'highlightColor': highlightColor,
    'englishFontSize': englishFontSize,
    'arabicFontSize': arabicFontSize,
    'playbackRate': playbackRate,
    'wordPlaybackRate': wordPlaybackRate,
    'readerVoiceId': readerVoiceId,
  };
}

class NovelReaderPreferencesStore {
  static const _boxName = 'novel_reader_preferences';

  Future<NovelReaderPreferences?> load(String novelId) async {
    final box = await _openBox();
    final raw = box.get(novelId);
    if (raw is! Map) return null;
    return NovelReaderPreferences.fromMap(raw);
  }

  Future<void> save(String novelId, NovelReaderPreferences settings) async {
    final box = await _openBox();
    await box.put(novelId, settings.toMap());
  }

  Future<Box<dynamic>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box<dynamic>(_boxName);
    return Hive.openBox<dynamic>(_boxName);
  }
}
