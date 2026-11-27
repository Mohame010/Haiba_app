part of '../novel_reader_state.dart';

extension _ReaderContent on NovelReaderState {
  Widget _buildReader(NovelChapter chapter) {
    return NovelReaderTextView(
      chapter: chapter,
      scrollController: _readerScrollController,
      englishFontSize: _englishFontSize,
      arabicFontSize: _arabicFontSize,
      textColor: _textColor,
      highlightColor: _highlightColor,
      highlightedWords: _highlightedWords,
      chapterNotes: _chapterNotes,
      wordKeys: _wordKeys,
      activeWordStart: _activeWordStart,
      activeWordEnd: _activeWordEnd,
      pageColor: _pageColor,
      primaryColor: AppColors.primary,
      onShowChrome: _showReadingChrome,
      onOpenWord: (word, anchorKey, sourceStart, sourceEnd) {
        _openWord(
          word,
          anchorKey: anchorKey,
          sourceStart: sourceStart,
          sourceEnd: sourceEnd,
        );
      },
      onOpenNote: (word, anchorKey, note) =>
          _showWordNote(word, anchorKey, note),
    );
  }

  void _showReadingChrome() {
    if (_readingFocusMode) _updateState(() => _readingFocusMode = false);
  }

  Color _foregroundFor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : const Color(0xff17202A);
  }

  Widget _buildFloatingNotes() {
    final isPlaying = _player.playing;
    return Positioned(
      right: 16,
      top: 76,
      width: math.min(300.0, MediaQuery.sizeOf(context).width - 32),
      child: Material(
        color: Colors.transparent,
        child: Card(
          color: Theme.of(
            context,
          ).colorScheme.surface.withValues(alpha: isPlaying ? .46 : .9),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'ملاحظات الفصل',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'إخفاء الملاحظات',
                      onPressed: () =>
                          _updateState(() => _notesFloatingVisible = false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                if (_chapterNotes.isEmpty)
                  const Text('لا توجد ملاحظات. اضغط على كلمة لإضافة ملاحظة.')
                else
                  for (final entry in _chapterNotes.entries)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text(entry.value),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
