part of '../novel_reader_state.dart';

extension _ReaderPlayerWidget on NovelReaderState {
  Widget _buildPlayer(NovelChapter chapter) {
    return NovelReaderPlayerPanel(
      isPlaying: _player.playing,
      isCompleted: _isNovelPlaybackCompleted,
      hasRecordedAudio: chapter.hasRecordedAudioConfigured,
      downloadProgress: _downloadProgress,
      listeningStatus: _hasSubscription
          ? 'اشتراك نشط • استماع بلا حد'
          : '${(_listeningSeconds + _pendingListeningSeconds) ~/ 60}:'
                '${((_listeningSeconds + _pendingListeningSeconds) % 60).toString().padLeft(2, '0')}'
                ' / 03:00',
      playbackRateLabel: _playbackRateLabel,
      readerVoiceId: _readerVoiceId,
      femaleVoiceId: _femaleVoiceId,
      maleVoiceId: _maleVoiceId,
      onSeekBy: _seekBy,
      onToggleAudio: _toggleAudio,
      onPlaybackRateChanged: _setPlaybackRate,
      onReaderVoiceChanged: _setReaderVoice,
      onToggleNotes: () =>
          _updateState(() => _notesFloatingVisible = !_notesFloatingVisible),
      onEnterFocusMode: () => _updateState(() => _readingFocusMode = true),
      onSavedWords: _showSavedWords,
      savedWordsCount: _savedWordsCount,
    );
  }
}
