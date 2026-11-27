part of '../novel_reader_state.dart';

extension _ReaderWordCards on NovelReaderState {
  Widget _buildWordLoadingCard(String word) => Directionality(
    textDirection: TextDirection.rtl,
    child: Shimmer.fromColors(
      baseColor: const Color(0xFFE8E8E8),
      highlightColor: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              word,
              style: const TextStyle(
                color: Color(0xff17202A),
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _wordShimmerBar(180, 20),
          const SizedBox(height: 8),
          _wordShimmerBar(120, 14),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: List.generate(
              4,
              (_) => const Padding(
                padding: EdgeInsetsDirectional.only(start: 12),
                child: CircleAvatar(radius: 18, backgroundColor: Colors.white),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _wordShimmerBar(double width, double height) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );

  Widget _buildWordErrorCard(
    String word,
    Object? error, {
    required VoidCallback onRetry,
  }) {
    final isNetworkIssue = _isNetworkError(error);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  word,
                  style: const TextStyle(
                    color: Color(0xff17202A),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'IBM',
                  ),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isNetworkIssue
                      ? const Color(0xFFFFF7ED)
                      : const Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isNetworkIssue
                      ? Icons.wifi_off_rounded
                      : Icons.error_outline_rounded,
                  size: 20,
                  color: isNetworkIssue
                      ? const Color(0xFFEA580C)
                      : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isNetworkIssue
                  ? const Color(0xFFFFFBEB)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isNetworkIssue
                    ? const Color(0xFFFDE68A)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isNetworkIssue
                          ? Icons.signal_wifi_bad_rounded
                          : Icons.info_outline_rounded,
                      size: 16,
                      color: isNetworkIssue
                          ? const Color(0xFFD97706)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isNetworkIssue
                            ? 'يحتاج اتصال بالإنترنت'
                            : 'تعذر جلب معنى الكلمة',
                        style: TextStyle(
                          color: isNetworkIssue
                              ? const Color(0xFF9A3412)
                              : const Color(0xFF1E293B),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'IBM',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isNetworkIssue
                      ? 'يرجى التحقق من اتصال الشبكة والضغط على إعادة المحاولة.'
                      : 'حدث خطأ أثناء الاتصال بالقاموس. يرجى إعادة المحاولة.',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontFamily: 'IBM',
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(
              'إعادة المحاولة',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                fontFamily: 'IBM',
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isNetworkError(Object? error) {
    if (error == null) return true;
    final msg = error.toString().toLowerCase();
    return msg.contains('socket') ||
        msg.contains('لا يتوفر اتصال') ||
        msg.contains('network') ||
        msg.contains('connection') ||
        msg.contains('timeout') ||
        msg.contains('failed host lookup') ||
        msg.contains('offline') ||
        msg.contains('clientexception') ||
        msg.contains('handshake') ||
        msg.contains('http') ||
        msg.contains('os error') ||
        msg.contains('errno');
  }

  Widget _buildWordCard(
    NovelWord word,
    Novel novel,
    BuildContext dialogContext, {
    required int? sourceStart,
    required int? sourceEnd,
  }) {
    var speaking = false;
    return StatefulBuilder(
      builder: (context, setCardState) => Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                word.word,
                style: const TextStyle(
                  color: Color(0xff17202A),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'IBM',
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              word.arabicMeaning,
              style: const TextStyle(
                color: Color(0xff17202A),
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'IBM',
              ),
            ),
            if (word.partOfSpeech != null && word.partOfSpeech!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                'نوع الكلمة: ${word.partOfSpeech}',
                style: const TextStyle(
                  color: Color(0xff52606D),
                  fontSize: 13,
                  fontFamily: 'IBM',
                ),
              ),
            ] else if (word.contextMeaning.isNotEmpty &&
                word.contextMeaning != word.arabicMeaning) ...[
              const SizedBox(height: 3),
              Text(
                'في السياق: ${word.contextMeaning}',
                style: const TextStyle(
                  color: Color(0xff52606D),
                  fontSize: 13,
                  fontFamily: 'IBM',
                ),
              ),
            ],
            const SizedBox(height: 3),
            Text(
              'النطق: ${word.transcription}',
              style: const TextStyle(
                color: Color(0xff52606D),
                fontSize: 13,
                fontFamily: 'IBM',
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'استمع',
                  onPressed: speaking
                      ? null
                      : () async {
                          setCardState(() => speaking = true);
                          var playbackStarted = false;
                          await _speakWord(
                            word.word,
                            sourceStart: sourceStart,
                            sourceEnd: sourceEnd,
                            onPlaybackStarted: () {
                              playbackStarted = true;
                              if (dialogContext.mounted) {
                                setCardState(() => speaking = false);
                              }
                            },
                          );
                          if (!playbackStarted && dialogContext.mounted) {
                            setCardState(() => speaking = false);
                          }
                        },
                  icon: speaking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.volume_up_rounded),
                ),
                PopupMenuButton<double>(
                  tooltip: 'سرعة نطق الكلمة',
                  initialValue: _wordPlaybackRate,
                  onSelected: _setWordPlaybackRate,
                  itemBuilder: (_) => [
                    for (final rate in [.5, .65, .75, .85, 1.0])
                      PopupMenuItem(
                        value: rate,
                        child: Text('${_formatPlaybackRate(rate)}x'),
                      ),
                  ],
                  child: SizedBox(
                    width: 44,
                    height: 48,
                    child: Center(
                      child: Text(
                        '${_formatPlaybackRate(_wordPlaybackRate)}x',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'حفظ الكلمة',
                  onPressed: () async {
                    await _repository.saveWord(
                      novelId: novel.id,
                      word: word,
                      novelTitle: novel.title,
                      chapterNumber: _chapter?.order ?? 0,
                    );
                    unawaited(_refreshSavedWordsCount());
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  icon: const Icon(Icons.bookmark_add_rounded),
                ),
                IconButton(
                  tooltip: 'تمييز الكلمة',
                  onPressed: () async {
                    await _saveHighlight(word);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  icon: const Icon(Icons.highlight_rounded),
                ),
                IconButton(
                  tooltip: 'ملاحظة',
                  onPressed: () => _editWordNote(word),
                  icon: const Icon(Icons.sticky_note_2_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
