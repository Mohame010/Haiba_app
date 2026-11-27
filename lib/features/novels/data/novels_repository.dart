import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import '../domain/novel_entities.dart';
import '../domain/novel_word_normalizer.dart';
import 'free_dictionary_service.dart';

typedef NovelWordDictionaryLoader =
    Future<Map<String, NovelWord>> Function(String novelId);
typedef ExternalNovelWordLookup = Future<WordResult> Function(String word);

class NovelsRepository {
  NovelsRepository({
    SupabaseClient? client,
    NovelWordDictionaryLoader? wordDictionaryLoader,
    ExternalNovelWordLookup? externalWordLookup,
  }) : this._(
         client: client,
         wordDictionaryLoader: wordDictionaryLoader,
         externalWordLookup: externalWordLookup,
       );

  NovelsRepository._({
    SupabaseClient? client,
    this._wordDictionaryLoader,
    ExternalNovelWordLookup? externalWordLookup,
  }) : _client = client ?? Supabase.instance.client,
       _externalWordLookup = externalWordLookup ?? _lookupExternalWord;

  final SupabaseClient _client;
  final NovelWordDictionaryLoader? _wordDictionaryLoader;
  final ExternalNovelWordLookup _externalWordLookup;
  static const _wordCacheBox = 'novel_word_cache';
  final Map<String, Future<Map<String, NovelWord>>> _wordDictionaries = {};

  Future<List<Novel>> fetchNovels({
    String? level,
    int offset = 0,
    int limit = 10,
  }) async {
    var query = _client
        .from('novels')
        .select('*, novel_chapters(id,title,sort_order)')
        .eq('is_published', true)
        .eq('category', 'novel');
    if (level != null && level.isNotEmpty) {
      query = query.eq('level', level);
    }
    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return rows
        .whereType<Map>()
        .map((row) => Novel.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<Novel?> fetchNovel(String novelId) async {
    final row = await _client
        .from('novels')
        .select('*, novel_chapters(*)')
        .eq('id', novelId)
        .eq('is_published', true)
        .maybeSingle();
    if (row == null) return null;
    final novel = Novel.fromMap(await _withSignedChapterAudio(row));
    if (novel.wordDictionary.isNotEmpty) {
      _wordDictionaries[novel.id] = Future.value(novel.wordDictionary);
    }
    return novel;
  }

  Future<Map<String, dynamic>> _withSignedChapterAudio(
    Map<String, dynamic> row,
  ) async {
    final chapters = row['novel_chapters'];
    if (chapters is! List) return row;
    final novelAudioPath = row['audio_storage_path']?.toString();
    final novelTimestampsPath = row['audio_timestamps_storage_path']
        ?.toString();
    final novelAudioRevision = (row['audio_revision'] as num?)?.toInt() ?? 1;
    final novelUrls =
        novelAudioPath != null &&
            novelAudioPath.isNotEmpty &&
            novelTimestampsPath != null &&
            novelTimestampsPath.isNotEmpty
        ? _createSignedAudioUrls(novelAudioPath, novelTimestampsPath)
        : null;
    final resolved = await Future.wait(
      chapters.whereType<Map>().map((chapter) async {
        final copy = Map<String, dynamic>.from(chapter);
        if ((copy['audio_url']?.toString().isNotEmpty ?? false) &&
            (copy['audio_timestamps_url']?.toString().isNotEmpty ?? false)) {
          return copy;
        }
        final chapterAudioPath = copy['audio_storage_path']?.toString();
        final chapterTimestampsPath = copy['audio_timestamps_storage_path']
            ?.toString();
        final hasChapterAudio =
            chapterAudioPath != null &&
            chapterAudioPath.isNotEmpty &&
            chapterTimestampsPath != null &&
            chapterTimestampsPath.isNotEmpty;
        final hasNovelAudio =
            novelAudioPath != null &&
            novelAudioPath.isNotEmpty &&
            novelTimestampsPath != null &&
            novelTimestampsPath.isNotEmpty;
        copy['recorded_audio_configured'] = hasChapterAudio || hasNovelAudio;
        final audioPath = hasChapterAudio ? chapterAudioPath : novelAudioPath;
        final timestampsPath = hasChapterAudio
            ? chapterTimestampsPath
            : novelTimestampsPath;
        if (audioPath == null ||
            audioPath.isEmpty ||
            timestampsPath == null ||
            timestampsPath.isEmpty) {
          return copy;
        }
        try {
          final urls = !hasChapterAudio && novelUrls != null
              ? await novelUrls
              : await _createSignedAudioUrls(audioPath, timestampsPath);
          copy['audio_url'] = urls[0];
          copy['audio_timestamps_url'] = urls[1];
          if (!hasChapterAudio) copy['audio_revision'] = novelAudioRevision;
        } catch (error) {
          copy['recorded_audio_error'] =
              'تعذر إنشاء رابط آمن لملفات الصوت: $error';
        }
        return copy;
      }),
    );
    return {...row, 'novel_chapters': resolved};
  }

  Future<List<String>> _createSignedAudioUrls(
    String audioPath,
    String timestampsPath,
  ) => Future.wait([
    _resolveNovelAudioUrl(audioPath),
    _resolveNovelAudioUrl(timestampsPath),
  ]);

  Future<String> _resolveNovelAudioUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      return Future.value(value);
    }
    var objectPath = value.replaceFirst(RegExp(r'^/+'), '');
    if (objectPath.startsWith('novel-audio/')) {
      objectPath = objectPath.substring('novel-audio/'.length);
    }
    return _client.storage
        .from('novel-audio')
        .createSignedUrl(objectPath, 60 * 60);
  }

  Future<bool> hasActiveSubscription() async {
    if (_client.auth.currentUser == null) return false;
    final rows = await _client
        .from('student_novel_subscriptions')
        .select('id')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<List<NovelSubscriptionPlan>> fetchSubscriptionPlans() async {
    final rows = await _client
        .from('novel_subscription_plans')
        .select(
          'id,name,duration_days,price,currency,listening_limit_seconds,listening_period,open_novels_limit,open_all_novels,open_poetry,open_podcasts,is_discount,old_price,new_price,description',
        )
        .eq('is_active', true)
        .order('sort_order');
    return rows
        .whereType<Map>()
        .map(
          (row) =>
              NovelSubscriptionPlan.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<Map<String, dynamic>> fetchLibrarySubscriptionStatus() async {
    if (_client.auth.currentUser == null)
      return const {'has_subscription': false, 'seconds_used': 0};
    final raw = await _client.rpc('get_library_subscription_status');
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<NovelWord?> findWord(String novelId, String word) async {
    final normalized = normalizeNovelWord(word);
    if (normalized.isEmpty) return null;

    // A meaning authored for this novel is contextual and must always win
    // over a generic Google translation.
    Object? dictionaryError;
    try {
      final dictionary = await _loadWordDictionary(novelId);
      final storedWord = dictionary[normalized];
      if (storedWord != null && storedWord.arabicMeaning.trim().isNotEmpty) {
        return _withSelectedWord(storedWord, word);
      }
    } catch (error) {
      dictionaryError = error;
    }

    final cache = await _openWordCache();
    final cacheKey = 'gdict_$normalized';
    final cached = cache.get(cacheKey);
    if (cached is Map) {
      final result = NovelWord.fromMap(Map<String, dynamic>.from(cached), word);
      return _withSelectedWord(result, word);
    }

    try {
      final res = await _externalWordLookup(normalized);
      final result = NovelWord(
        word: word,
        arabicMeaning: res.translatedText,
        contextMeaning: res.partOfSpeech.isNotEmpty
            ? 'نوع الكلمة: ${res.partOfSpeech}'
            : '',
        transcription: res.phonetic,
        audioUrl: res.audioUrl,
        partOfSpeech: res.partOfSpeech,
      );

      await cache.put(cacheKey, {
        'word': result.word,
        'arabic_meaning': result.arabicMeaning,
        'context_meaning': result.contextMeaning,
        'transcription': result.transcription,
        'audio_url': result.audioUrl,
        'part_of_speech': result.partOfSpeech,
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      });

      return result;
    } catch (_) {
      if (dictionaryError != null) throw dictionaryError;
      rethrow;
    }
  }

  NovelWord _withSelectedWord(NovelWord result, String selectedWord) =>
      NovelWord(
        word: selectedWord,
        arabicMeaning: result.arabicMeaning,
        contextMeaning: result.contextMeaning,
        transcription: result.transcription,
        novelTitle: result.novelTitle,
        chapterNumber: result.chapterNumber,
        audioUrl: result.audioUrl,
        partOfSpeech: result.partOfSpeech,
      );

  Future<Map<String, NovelWord>> _loadWordDictionary(String novelId) async {
    final pending = _wordDictionaries[novelId];
    if (pending != null) return pending;

    final request = _fetchWordDictionary(novelId);
    _wordDictionaries[novelId] = request;
    try {
      return await request;
    } catch (_) {
      _wordDictionaries.remove(novelId);
      rethrow;
    }
  }

  Future<Map<String, NovelWord>> _fetchWordDictionary(String novelId) async {
    final customLoader = _wordDictionaryLoader;
    if (customLoader != null) return customLoader(novelId);
    final rows = await _client
        .from('novel_words')
        .select('word,arabic_meaning,context_meaning,transcription')
        .eq('novel_id', novelId);
    final dictionary = <String, NovelWord>{};
    for (final row in rows) {
      final word = NovelWord.fromMap(Map<String, dynamic>.from(row), '');
      final normalized = normalizeNovelWord(word.word);
      if (normalized.isNotEmpty &&
          (dictionary[normalized] == null ||
              dictionary[normalized]!.arabicMeaning.isEmpty)) {
        dictionary[normalized] = word;
      }
    }
    return dictionary;
  }

  static Future<WordResult> _lookupExternalWord(String word) =>
      FreeDictionaryService.lookupWord(word: word);

  Future<Box<dynamic>> _openWordCache() async {
    if (Hive.isBoxOpen(_wordCacheBox)) {
      return Hive.box<dynamic>(_wordCacheBox);
    }
    return Hive.openBox<dynamic>(_wordCacheBox);
  }

  Future<Set<String>> loadHighlights(String chapterId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};
    final rows = await _client
        .from('novel_annotations')
        .select('selected_text')
        .eq('student_id', userId)
        .eq('chapter_id', chapterId)
        .eq('annotation_type', 'highlight');
    return rows
        .map((row) => row['selected_text']?.toString().toLowerCase())
        .whereType<String>()
        .toSet();
  }

  Future<Map<String, String>> loadNotes(String chapterId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};
    final rows = await _client
        .from('novel_annotations')
        .select('selected_text,note')
        .eq('student_id', userId)
        .eq('chapter_id', chapterId)
        .eq('annotation_type', 'note');
    return {
      for (final row in rows)
        if (row['selected_text'] is String && row['note'] is String)
          normalizeNovelWord(row['selected_text'] as String):
              row['note'] as String,
    };
  }

  Future<void> saveWord({
    required String novelId,
    required NovelWord word,
    required String novelTitle,
    required int chapterNumber,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('سجّل الدخول لحفظ الكلمات.');
    final payload = <String, dynamic>{
      'student_id': userId,
      'novel_id': novelId,
      'word': word.word,
      'arabic_meaning': word.arabicMeaning,
      'context_meaning': word.contextMeaning,
      'transcription': word.transcription,
      'novel_title': novelTitle,
      'chapter_number': chapterNumber,
    };
    try {
      await _client.from('acquired_novel_words').upsert(payload);
    } catch (e) {
      final err = e.toString().toLowerCase();
      if (err.contains('foreign key') || err.contains('fkey')) {
        final fallback = await _client
            .from('novels')
            .select('id')
            .limit(1)
            .maybeSingle();
        if (fallback != null && fallback['id'] != null) {
          payload['novel_id'] = fallback['id'] as String;
          await _client.from('acquired_novel_words').upsert(payload);
          return;
        }
      }
      rethrow;
    }
  }

  Future<List<NovelWord>> loadSavedWords({
    String? novelId,
    int offset = 0,
    int limit = 30,
    String? queryText,
  }) async {
    if (offset < 0) throw RangeError.value(offset, 'offset');
    if (limit <= 0) throw RangeError.value(limit, 'limit');
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    var query = _client
        .from('acquired_novel_words')
        .select(
          'word,arabic_meaning,context_meaning,transcription,novel_title,chapter_number',
        )
        .eq('student_id', userId);
    if (novelId != null) query = query.eq('novel_id', novelId);
    final trimmedQuery = queryText?.trim();
    if (trimmedQuery != null && trimmedQuery.isNotEmpty) {
      final escapedQuery = trimmedQuery
          .replaceAll(r'\', r'\\')
          .replaceAll('"', r'\"');
      final pattern = '"%$escapedQuery%"';
      final filters = <String>[
        'word.ilike.$pattern',
        'novel_title.ilike.$pattern',
      ];
      final chapterMatch = RegExp(
        r'^(?:(?:شابتر|فصل|chapter)\s*)?(\d+)$',
        caseSensitive: false,
      ).firstMatch(trimmedQuery);
      if (chapterMatch != null) {
        filters.add('chapter_number.eq.${chapterMatch.group(1)}');
      }
      query = query.or(filters.join(','));
    }
    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return rows
        .whereType<Map>()
        .map((row) => NovelWord.fromMap(Map<String, dynamic>.from(row), ''))
        .toList();
  }

  Future<int> countSavedWords({String? novelId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;
    var query = _client
        .from('acquired_novel_words')
        .select('word')
        .eq('student_id', userId);
    if (novelId != null) query = query.eq('novel_id', novelId);
    final rows = await query;
    return rows.length;
  }

  Future<void> saveAnnotation({
    required String novelId,
    required String chapterId,
    required String selectedText,
    required String type,
    String? note,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('سجّل الدخول لحفظ علامات القراءة.');
    await _client.from('novel_annotations').upsert({
      'student_id': userId,
      'novel_id': novelId,
      'chapter_id': chapterId,
      'selected_text': selectedText,
      'annotation_type': type,
      'note': note,
    }, onConflict: 'student_id,chapter_id,selected_text,annotation_type');
  }
}
