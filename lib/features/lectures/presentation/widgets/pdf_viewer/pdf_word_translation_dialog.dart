import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:just_audio/just_audio.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/services/tts_cache_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../novels/data/free_dictionary_service.dart';
import '../../../../novels/data/novels_repository.dart';
import '../../../../novels/domain/novel_entities.dart';
import '../../../../novels/presentation/widgets/novel_saved_words_screen.dart';

class PdfWordTranslationDialog extends StatefulWidget {
  const PdfWordTranslationDialog({
    super.key,
    required this.rawWord,
    required this.pdfTitle,
  });

  final String rawWord;
  final String pdfTitle;

  static Future<void> show(
    BuildContext context, {
    required String word,
    required String pdfTitle,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          PdfWordTranslationDialog(rawWord: word, pdfTitle: pdfTitle),
    );
  }

  @override
  State<PdfWordTranslationDialog> createState() =>
      _PdfWordTranslationDialogState();
}

class _PdfWordTranslationDialogState extends State<PdfWordTranslationDialog> {
  final _repository = NovelsRepository();
  final _player = AudioPlayer();

  late final String _cleanWord;
  late final String _pdfUuid;

  bool _isLoading = true;
  String? _errorMessage;
  WordResult? _wordResult;

  bool _isPlayingAudio = false;
  bool _isSaving = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _cleanWord = _sanitizeWord(widget.rawWord);
    _pdfUuid = _generateDeterministicUuid(widget.pdfTitle);
    _fetchTranslation();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _sanitizeWord(String input) {
    // Remove unwanted leading/trailing symbols, brackets, and punctuation
    return input
        .replaceAll(
          RegExp(r"^[^a-zA-Z0-9\u0600-\u06FF]+|[^a-zA-Z0-9\u0600-\u06FF]+$"),
          '',
        )
        .trim();
  }

  String _generateDeterministicUuid(String title) {
    final clean = title.trim().toLowerCase();
    final hash = md5
        .convert(utf8.encode(clean.isNotEmpty ? clean : 'pdf_doc'))
        .toString();
    return '${hash.substring(0, 8)}-${hash.substring(8, 12)}-${hash.substring(12, 16)}-${hash.substring(16, 20)}-${hash.substring(20, 32)}';
  }

  Future<void> _fetchTranslation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await FreeDictionaryService.lookupWord(
        word: _cleanWord.isNotEmpty ? _cleanWord : widget.rawWord.trim(),
      );
      if (!mounted) return;
      setState(() {
        _wordResult = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _playPronunciation() async {
    if (_isPlayingAudio) return;
    setState(() => _isPlayingAudio = true);

    try {
      final targetWord = (_wordResult?.originalWord ?? _cleanWord).trim();
      if (targetWord.isNotEmpty) {
        await TtsCacheService.instance.pronounce(
          _player,
          targetWord,
          onPlaybackStarted: () {
            if (mounted) setState(() => _isPlayingAudio = true);
          },
        );
      }
    } catch (_) {
      // Audio playback failed silently
    } finally {
      if (mounted) {
        setState(() => _isPlayingAudio = false);
      }
    }
  }

  Future<void> _saveWord() async {
    if (_wordResult == null || _isSaved || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      final novelWord = NovelWord(
        word: _wordResult!.originalWord,
        arabicMeaning: _wordResult!.translatedText,
        contextMeaning: _wordResult!.translatedText,
        transcription: _wordResult!.phonetic != 'غير متوفر'
            ? _wordResult!.phonetic
            : '',
        novelTitle: widget.pdfTitle,
        chapterNumber: 0, // 0 indicates saved from a PDF document
        audioUrl: _wordResult!.audioUrl,
        partOfSpeech: _wordResult!.partOfSpeech,
      );

      await _repository.saveWord(
        novelId: _pdfUuid,
        word: novelWord,
        novelTitle: widget.pdfTitle,
        chapterNumber: 0,
      );

      if (!mounted) return;
      setState(() {
        _isSaved = true;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تمت إضافة "${_wordResult!.originalWord}" إلى حصيلة الكلمات',
            style: const TextStyle(fontFamily: 'IBM'),
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر حفظ الكلمة: $e',
            style: const TextStyle(fontFamily: 'IBM'),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20.w,
          right: 20.w,
          top: 14.h,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44.w,
                height: 4.5.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
            SizedBox(height: 16.h),

            // Top Bar: Source PDF Badge & Close
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: const Color(0xFFFECACA),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 15.sp,
                          color: const Color(0xFFDC2626),
                        ),
                        SizedBox(width: 6.w),
                        Flexible(
                          child: Text(
                            widget.pdfTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFB91C1C),
                              fontFamily: 'IBM',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                IconButton(
                  tooltip: 'عرض حصيلة الكلمات',
                  onPressed: () {
                    Navigator.pop(context);
                    NovelSavedWordsScreen.open(context);
                  },
                  icon: const Icon(
                    Icons.collections_bookmark_rounded,
                    color: AppColors.primary,
                  ),
                ),
                IconButton(
                  tooltip: 'إغلاق',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                ),
              ],
            ),
            SizedBox(height: 14.h),

            if (_isLoading) ...[
              Padding(
                padding: EdgeInsets.symmetric(vertical: 32.h),
                child: Column(
                  children: [
                    const CircularProgressIndicator(strokeWidth: 2.5),
                    SizedBox(height: 16.h),
                    Text(
                      'جاري ترجمة الكلمة ونطقها...',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.textSecondary,
                        fontFamily: 'IBM',
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_errorMessage != null) ...[
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24.h),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 40.sp,
                      color: AppColors.error,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        color: AppColors.error,
                        fontFamily: 'IBM',
                      ),
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton.icon(
                      onPressed: _fetchTranslation,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text(
                        'إعادة المحاولة',
                        style: TextStyle(fontFamily: 'IBM'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_wordResult != null) ...[
              // Word Title & Pronunciation Action
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      _wordResult!.originalWord,
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _isPlayingAudio ? null : _playPronunciation,
                    borderRadius: BorderRadius.circular(16.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: const Color(0xFFC7D2FE),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isPlayingAudio)
                            SizedBox(
                              width: 18.w,
                              height: 18.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF4F46E5),
                              ),
                            )
                          else
                            Icon(
                              Icons.volume_up_rounded,
                              size: 20.sp,
                              color: const Color(0xFF4F46E5),
                            ),
                          SizedBox(width: 6.w),
                          Text(
                            _isPlayingAudio ? 'جارٍ النطق...' : 'استمع للنطق',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF4F46E5),
                              fontFamily: 'IBM',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),

              // Chips: Phonetics & Part of Speech
              Row(
                children: [
                  if (_wordResult!.phonetic != 'غير متوفر') ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        _wordResult!.phonetic,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: const Color(0xFF475569),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                  ],
                  if (_wordResult!.partOfSpeech.isNotEmpty) ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E7FF),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        _wordResult!.partOfSpeech,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4338CA),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 16.h),

              // Arabic Translation Container
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الترجمة:',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textSecondary,
                        fontFamily: 'IBM',
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _wordResult!.translatedText,
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                        fontFamily: 'IBM',
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),

              // Save to Vocabulary Button
              SizedBox(
                height: 48.h,
                child: FilledButton.icon(
                  onPressed: _isSaved ? null : _saveWord,
                  icon: _isSaving
                      ? SizedBox(
                          width: 18.w,
                          height: 18.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _isSaved
                              ? Icons.check_circle_rounded
                              : Icons.bookmark_add_rounded,
                          size: 20.sp,
                        ),
                  label: Text(
                    _isSaved
                        ? 'تمت الإضافة إلى حصيلة الكلمات'
                        : 'إضافة إلى حصيلة الكلمات',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'IBM',
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _isSaved
                        ? const Color(0xFF059669)
                        : AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
