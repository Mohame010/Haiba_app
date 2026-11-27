part of '../novel_reader_state.dart';

extension _ReaderNavigation on NovelReaderState {
  Future<void> _showPaywall(String message) async {
    final paid = await NovelSubscriptionSheet.show(context, message: message);
    if (paid != true || !mounted) return;
    final status = await _quota.loadStatus();
    if (!mounted) return;
    _updateState(() {
      _hasSubscription = status.hasSubscription;
      _listeningSeconds = status.secondsUsed;
    });
    if (_subscriptionRequired && status.hasSubscription) {
      _updateState(() {
        _loading = true;
        _subscriptionRequired = false;
      });
      await _loadNovel();
    }
  }

  Future<void> _selectChapter(
    NovelChapter chapter, {
    bool autoplay = true,
  }) async {
    if (_switchingChapter || _chapter?.id == chapter.id) return;
    _switchingChapter = true;
    _cancelNextChapterCountdown();
    try {
      await _saveReadingPreferences();
      await _player.stop();
      await _wordPlayer.stop();
      if (!mounted) return;
      _updateState(() {
        _chapter = chapter;
        _novelCompleted = false;
        _speechAudio = null;
        _speechSegments.clear();
        _speechSegmentOffsets.clear();
        _speechSegmentSourceOffsets.clear();
        _speechChunks = const [];
        _speechSegmentIndex = 0;
        _position = Duration.zero;
        _duration = Duration.zero;
        _positionNotifier.value = Duration.zero;
        _activeWordStart = null;
        _activeWordEnd = null;
        _pendingAutoScrollStart = null;
        _highlightedWords.clear();
        _chapterNotes.clear();
        _wordKeys.clear();
      });
      if (_readerScrollController.hasClients) {
        _readerScrollController.jumpTo(0);
      }
      // Try server pre-generated audio first (instant playback).
      final preGenLoaded = await _tryPreGeneratedAudio(chapter);
      if (!preGenLoaded && !chapter.hasRecordedAudioConfigured) {
        final restored = await _restorePreparedChapter(chapter);
        if (!restored) await _restoreChapterAudio(chapter);
      }
      unawaited(_loadAnnotations(chapter.id));
    } finally {
      _switchingChapter = false;
    }
    if (autoplay && mounted) {
      _updatePosition(_position);
      await _toggleAudio();
    }
  }

  Future<void> _restartNovel() async {
    final novel = _novel;
    if (novel == null || novel.chapters.isEmpty) return;
    final firstChapter = novel.chapters.first;
    if (_chapter?.id != firstChapter.id) {
      await _selectChapter(firstChapter, autoplay: false);
    } else {
      await _player.stop();
      _cancelNextChapterCountdown();
    }
    if (!mounted) return;
    _updateState(() {
      _novelCompleted = false;
      _position = Duration.zero;
      _positionNotifier.value = Duration.zero;
      _speechSegmentIndex = 0;
      _activeWordStart = null;
      _activeWordEnd = null;
    });
    if (_readerScrollController.hasClients) {
      _readerScrollController.jumpTo(0);
    }
    await _prepareAndPlay(fromBeginning: true);
  }
}
