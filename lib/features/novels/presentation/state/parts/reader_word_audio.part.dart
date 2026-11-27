part of '../novel_reader_state.dart';

extension _ReaderWordAudio on NovelReaderState {
  Future<void> _speakWord(
    String word, {
    int? sourceStart,
    int? sourceEnd,
    VoidCallback? onPlaybackStarted,
  }) async {
    if (_wordLoading) return;
    final novel = _novel;
    if (novel == null) return;
    final resumeNarration = _player.playing;
    _updateState(() => _wordLoading = true);
    try {
      if (resumeNarration) await _player.pause();
      await _wordPlayer.stop();
      await _wordPlayer.setSpeed(_wordPlaybackRate);

      final cleanWord = word.trim();
      if (cleanWord.isEmpty) return;

      await TtsCacheService.instance.pronounce(
        _wordPlayer,
        cleanWord,
        onPlaybackStarted: onPlaybackStarted,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر نطق الكلمة: $error')));
      }
    } finally {
      if (resumeNarration && mounted && !_player.playing) {
        await _player.play();
      }
      if (mounted) {
        _updateState(() => _wordLoading = false);
      }
    }
  }
}
