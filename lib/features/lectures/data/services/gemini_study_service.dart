import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/network/internet_connection_mixin.dart';

class AiQuestion {
  final String type;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String explanation;

  const AiQuestion({
    required this.type,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });

  factory AiQuestion.fromJson(Map<String, dynamic> json) => AiQuestion(
    type: json['type'] as String? ?? 'multiple_choice',
    question: json['question'] as String? ?? '',
    options: (json['options'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(),
    correctAnswer: json['correctAnswer']?.toString() ?? '',
    explanation: json['explanation'] as String? ?? '',
  );
}

class AiStudyPack {
  final String summary;
  final List<AiQuestion> questions;

  const AiStudyPack({required this.summary, required this.questions});
}

class GeminiStudyService with InternetConnectionMixin {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _model = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-2.5-flash',
  );

  bool get isConfigured => _apiKey.trim().isNotEmpty;

  Future<AiStudyPack> analyzePdf({
    required String pdfPath,
    required Set<String> questionTypes,
    required int questionCount,
  }) async {
    if (!isConfigured) {
      throw StateError(
        'أضف GEMINI_API_KEY باستخدام --dart-define عند تشغيل أو بناء التطبيق',
      );
    }
    final bytes = await File(pdfPath).readAsBytes();
    final requestedTypes = questionTypes.join(', ');
    final endpoint = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent?key=$_apiKey',
    );
    final response = await runWithInternetConnection(
      () => http.post(
        endpoint,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'inline_data': {
                    'mime_type': 'application/pdf',
                    'data': base64Encode(bytes),
                  },
                },
                {
                  'text':
                      'حلل هذا الملف التعليمي باللغة العربية. قدم ملخصاً واضحاً '
                      'ثم أنشئ $questionCount سؤالاً تفاعلياً. الأنواع المطلوبة: '
                      '$requestedTypes. في multiple_choice اجعل options أربع اختيارات '
                      'واجعل correctAnswer نص الاختيار الصحيح نفسه. في true_false اجعل '
                      'options ["صح","خطأ"] والإجابة واحدة منهما. في short_answer '
                      'اجعل الإجابة مختصرة ودقيقة. لا تستخدم معلومات خارج الملف.',
                },
              ],
            },
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
            'responseSchema': {
              'type': 'OBJECT',
              'properties': {
                'summary': {'type': 'STRING'},
                'questions': {
                  'type': 'ARRAY',
                  'items': {
                    'type': 'OBJECT',
                    'properties': {
                      'type': {'type': 'STRING'},
                      'question': {'type': 'STRING'},
                      'options': {
                        'type': 'ARRAY',
                        'items': {'type': 'STRING'},
                      },
                      'correctAnswer': {'type': 'STRING'},
                      'explanation': {'type': 'STRING'},
                    },
                    'required': [
                      'type',
                      'question',
                      'options',
                      'correctAnswer',
                      'explanation',
                    ],
                  },
                },
              },
              'required': ['summary', 'questions'],
            },
          },
        }),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final message = (body?['error'] as Map?)?['message']?.toString();
      throw HttpException(message ?? 'Gemini HTTP ${response.statusCode}');
    }
    final root = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = root['candidates'] as List<dynamic>? ?? const [];
    if (candidates.isEmpty) {
      throw const FormatException('لم يُرجع Gemini نتيجة');
    }
    final content = (candidates.first as Map)['content'] as Map;
    final parts = content['parts'] as List;
    final text = (parts.first as Map)['text'] as String;
    final data = jsonDecode(text) as Map<String, dynamic>;
    return AiStudyPack(
      summary: data['summary'] as String? ?? '',
      questions: (data['questions'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                AiQuestion.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}
