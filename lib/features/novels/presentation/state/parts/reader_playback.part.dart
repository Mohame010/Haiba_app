part of '../novel_reader_state.dart';

extension _ReaderPlayback on NovelReaderState {
  bool get _isNovelPlaybackCompleted {
    if (_novelCompleted) return true;

    final novel = _novel;
    final chapter = _chapter;
    if (novel == null || chapter == null || novel.chapters.isEmpty) {
      return false;
    }

    final isLastChapter = novel.chapters.last.id == chapter.id;
    final isLastSpeechSegment =
        _speechChunks.isNotEmpty &&
        _speechSegmentIndex == _speechChunks.length - 1;
    return isLastChapter &&
        isLastSpeechSegment &&
        _player.processingState == just_audio.ProcessingState.completed;
  }

  Future<void> _prepareAndPlay({bool fromBeginning = false}) async {
    final chapter = _chapter;
    final novel = _novel;
    if (chapter == null || novel == null || _modelLoading) return;

    // ── Try server pre-generated audio first (instant, no TTS needed) ──
    if (chapter.hasRecordedAudioConfigured) {
      _updateState(() {
        _modelLoading = true;
        _downloadProgress = null;
      });
      Object? recordedAudioFailure;
      try {
        final loaded = await _tryPreGeneratedAudio(chapter);
        if (loaded && mounted) {
          final savedMs = fromBeginning ? 0 : _position.inMilliseconds;
          await _playCurrentSpeechSegment(
            position:
                savedMs > 0 &&
                    savedMs < _speechSegments.first.duration.inMilliseconds
                ? Duration(milliseconds: savedMs)
                : null,
          );
          return;
        }
        recordedAudioFailure =
            chapter.recordedAudioError ??
            _speech.lastPreGeneratedAudioError ??
            'لم يتم العثور على رابط صالح للصوت وملف التوقيت.';
      } catch (error, stackTrace) {
        recordedAudioFailure = error;
        AppLogger.log(
          'تعذر تشغيل الصوت المسجل للرواية',
          name: 'NOVEL_AUDIO',
          error: error,
          stackTrace: stackTrace,
        );
      } finally {
        if (mounted) {
          _updateState(() {
            _modelLoading = false;
            _downloadProgress = null;
          });
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'الصوت المسجل مضاف للرواية لكن تعذر تشغيله. '
              'لن يتم تنزيل موديل الراوي.\n$recordedAudioFailure',
            ),
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يتوفر تسجيل صوتي لهذا الفصل حاليًا.')),
      );
    }
  }

  Future<void> _toggleAudio() async {
    if (_isNovelPlaybackCompleted) {
      await _restartNovel();
      return;
    }
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (_modelLoading) return;
    if (_usageLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جارٍ التحقق من وقت الاستماع اليومي')),
      );
      return;
    }
    if (!_hasSubscription &&
        !_player.playing &&
        _listeningSeconds >= NovelListeningQuota.dailyFreeSeconds) {
      _showPaywall('انتهت دقائق الاستماع المجانية لهذا اليوم');
      return;
    }
    if (_pendingListeningSeconds > 0) {
      await _flushListeningSeconds();
      if (!mounted ||
          (!_hasSubscription &&
              _listeningSeconds >= NovelListeningQuota.dailyFreeSeconds)) {
        return;
      }
    }
    try {
      if (_speechAudio == null) {
        await _prepareAndPlay();
      } else if (_player.processingState == just_audio.ProcessingState.ready) {
        await _player.play();
      } else {
        await _playCurrentChapter();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تشغيل صوت الرواية: $error')),
        );
      }
    }
  }

  Future<void> _playCurrentChapter() async {
    if (_speechSegments.isEmpty) {
      await _prepareAndPlay();
      return;
    }
    final offset = _speechSegmentOffsets[_speechSegmentIndex];
    final localPosition = _position > offset ? _position - offset : null;
    await _playCurrentSpeechSegment(position: localPosition);
  }
}
