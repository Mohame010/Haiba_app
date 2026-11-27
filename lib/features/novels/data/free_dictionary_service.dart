import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/network/internet_connection_mixin.dart';

class WordResult {
  final String originalWord;
  final String translatedText;
  final String phonetic; // النطق الصوتي مثل: /həˈləʊ/
  final String audioUrl; // رابط ملف الصوت للنطق
  final String partOfSpeech; // نوع الكلمة (noun, verb...)

  WordResult({
    required this.originalWord,
    required this.translatedText,
    required this.phonetic,
    required this.audioUrl,
    required this.partOfSpeech,
  });
}

class FreeDictionaryService with InternetConnectionMixin {
  const FreeDictionaryService();

  static Future<WordResult> lookupWord({
    required String word,
    String fromLang = 'en',
    String toLang = 'ar',
  }) async {
    return const FreeDictionaryService()._lookupWord(
      word: word,
      fromLang: fromLang,
      toLang: toLang,
    );
  }

  Future<WordResult> _lookupWord({
    required String word,
    required String fromLang,
    required String toLang,
  }) => runWithInternetConnection(() async {
    final cleanWord = word.trim();

    // 1. ترجمة جوجل المجانية بالكامل وبدون أي API Key (أعلى دقة وسرعة)
    final googleUri = Uri.parse(
      'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$fromLang&tl=$toLang&dt=t&dt=bd&q=${Uri.encodeComponent(cleanWord)}',
    );

    // 2. Free Dictionary API لجلب الـ Transcription والصوت
    final dictUri = Uri.https(
      'api.dictionaryapi.dev',
      '/api/v2/entries/en/${Uri.encodeComponent(cleanWord)}',
    );

    // تنفيذ الطلبين معاً بالتوازي لأفضل سرعة
    Object? networkError;
    final responses = await Future.wait([
      http.get(googleUri).timeout(const Duration(seconds: 10)).catchError((e) {
        networkError = e;
        return http.Response('', 500);
      }),
      http.get(dictUri).timeout(const Duration(seconds: 10)).catchError((e) {
        networkError ??= e;
        return http.Response('', 500);
      }),
    ]);

    final googleRes = responses[0];
    final dictRes = responses[1];

    String translated = '';
    String pos = '';

    // استخراج الترجمة الدقيقة من Google Translate
    if (googleRes.statusCode == 200) {
      try {
        final dynamic data = jsonDecode(googleRes.body);
        if (data is List && data.isNotEmpty && data[0] is List) {
          final buffer = StringBuffer();
          for (final part in (data[0] as List)) {
            if (part is List && part.isNotEmpty && part[0] != null) {
              buffer.write(part[0].toString());
            }
          }
          translated = buffer.toString().trim();
        }

        // استخراج نوع الكلمة (noun, verb...) من معطيات جوجل إن وجدت
        if (data is List &&
            data.length > 1 &&
            data[1] is List &&
            (data[1] as List).isNotEmpty) {
          final firstDict = (data[1] as List)[0];
          if (firstDict is List &&
              firstDict.isNotEmpty &&
              firstDict[0] != null) {
            pos = firstDict[0].toString();
          }
        }
      } catch (_) {}
    }

    // بديل احتياطي في حال تعذر ترجمة جوجل
    if (translated.isEmpty && networkError == null) {
      try {
        final myMemoryUri = Uri.https('api.mymemory.translated.net', '/get', {
          'q': cleanWord,
          'langpair': '$fromLang|$toLang',
        });
        final myMemoryRes = await http
            .get(myMemoryUri)
            .timeout(const Duration(seconds: 5))
            .catchError((_) => http.Response('', 500));
        if (myMemoryRes.statusCode == 200) {
          final data = jsonDecode(myMemoryRes.body);
          translated = (data['responseData']?['translatedText'] ?? '')
              .toString()
              .trim();
        }
      } catch (_) {}
    }

    String phonetic = '';
    String audio = '';

    // استخراج الـ Transcription والصوت إذا كانت الكلمة إنجليزية وموجودة في القاموس
    if (dictRes.statusCode == 200) {
      try {
        final dynamic dictData = jsonDecode(dictRes.body);
        if (dictData is List && dictData.isNotEmpty) {
          final firstEntry = dictData[0];

          // البحث عن الـ phonetic
          phonetic = firstEntry['phonetic']?.toString() ?? '';
          final phoneticsList = firstEntry['phonetics'] as List<dynamic>? ?? [];

          for (var p in phoneticsList) {
            if (phonetic.isEmpty &&
                p['text'] != null &&
                p['text'].toString().isNotEmpty) {
              phonetic = p['text'].toString();
            }
            if (audio.isEmpty &&
                p['audio'] != null &&
                p['audio'].toString().isNotEmpty) {
              audio = p['audio'].toString();
            }
          }

          // نوع الكلمة (اسم، فعل، صفة...) إذا لم يكن مستخرجاً من جوجل
          if (pos.isEmpty) {
            final meanings = firstEntry['meanings'] as List<dynamic>? ?? [];
            if (meanings.isNotEmpty) {
              pos = meanings[0]['partOfSpeech']?.toString() ?? '';
            }
          }
        }
      } catch (_) {}
    }

    if (translated.isEmpty) {
      if (networkError != null) {
        throw networkError!;
      }
      throw Exception('لم يتم العثور على ترجمة');
    }

    if (audio.startsWith('//')) {
      audio = 'https:$audio';
    }

    if (audio.isEmpty && cleanWord.isNotEmpty) {
      audio =
          'https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=$fromLang&q=${Uri.encodeComponent(cleanWord)}';
    }

    return WordResult(
      originalWord: cleanWord,
      translatedText: translated,
      phonetic: phonetic.isNotEmpty ? phonetic : 'غير متوفر',
      audioUrl: audio,
      partOfSpeech: pos,
    );
  });
}
