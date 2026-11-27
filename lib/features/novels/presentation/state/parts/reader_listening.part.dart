part of '../novel_reader_state.dart';

extension _ReaderListening on NovelReaderState {
  void _onPlayerStateChanged(PlayerState state) {
    if (!mounted) return;
    if (state == PlayerState.playing) {
      _startListeningTimer();
      unawaited(_syncBackgroundPlayback());
    } else {
      _stopListeningTimer();
      unawaited(_flushListeningSeconds());
      unawaited(_syncBackgroundPlayback());
    }
    _updateState(() {});
  }

  void _startListeningTimer() {
    _listeningTimer ??= Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      if (_hasSubscription) {
        _subscriptionCheckCountdown--;
        if (_subscriptionCheckCountdown <= 0) {
          _subscriptionCheckCountdown = 30;
          try {
            final status = await _quota.loadStatus();
            if (!mounted) return;
            _updateState(() {
              _hasSubscription = status.hasSubscription;
              _listeningSeconds = status.secondsUsed;
            });
            if (!status.hasSubscription &&
                status.secondsUsed >= NovelListeningQuota.dailyFreeSeconds) {
              await _player.pause();
              unawaited(
                _showPaywall('انتهت دقائق الاستماع المجانية لهذا اليوم'),
              );
            }
          } catch (error) {
            await _pauseForQuotaError(error);
          }
        }
        return;
      }
      _pendingListeningSeconds++;
      _updateState(() {});
      if (_pendingListeningSeconds >= 5 ||
          _listeningSeconds + _pendingListeningSeconds >=
              NovelListeningQuota.dailyFreeSeconds) {
        await _flushListeningSeconds();
      }
    });
  }

  Future<void> _flushListeningSeconds() async {
    if (_quotaWriteInProgress ||
        _pendingListeningSeconds == 0 ||
        _hasSubscription) {
      return;
    }
    _quotaWriteInProgress = true;
    final pending = _pendingListeningSeconds;
    try {
      final status = await _quota.consumeSeconds(pending);
      _pendingListeningSeconds -= pending;
      if (!mounted) return;
      _updateState(() {
        _listeningSeconds = status.secondsUsed;
        _hasSubscription = status.hasSubscription;
      });
      if (!status.allowed ||
          (!status.hasSubscription &&
              status.secondsUsed >= NovelListeningQuota.dailyFreeSeconds)) {
        await _player.pause();
        unawaited(_showPaywall('انتهت دقائق الاستماع المجانية لهذا اليوم'));
      }
    } catch (error) {
      _pendingListeningSeconds = pending;
      await _pauseForQuotaError(error);
    } finally {
      _quotaWriteInProgress = false;
    }
  }

  Future<void> _pauseForQuotaError(Object error) async {
    await _player.pause();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تسجيل وقت الاستماع: $error')),
      );
    }
  }

  void _stopListeningTimer() {
    _listeningTimer?.cancel();
    _listeningTimer = null;
  }

  void _startNextChapterCountdown() {
    _chapterCountdownTimer?.cancel();
    final novel = _novel;
    final chapter = _chapter;
    if (novel == null || chapter == null) return;
    final index = novel.chapters.indexWhere((item) => item.id == chapter.id);
    if (index < 0 || index + 1 >= novel.chapters.length || !mounted) return;
    _updateState(() => _chapterCountdown = 2);
    _chapterCountdownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_chapterCountdown <= 1) {
        timer.cancel();
        _chapterCountdownTimer = null;
        _updateState(() => _chapterCountdown = 0);
        unawaited(_selectChapter(novel.chapters[index + 1]));
      } else {
        _updateState(() => _chapterCountdown--);
      }
    });
  }

  void _cancelNextChapterCountdown() {
    _chapterCountdownTimer?.cancel();
    _chapterCountdownTimer = null;
    if (mounted && _chapterCountdown != 0) {
      _updateState(() => _chapterCountdown = 0);
    }
  }
}
