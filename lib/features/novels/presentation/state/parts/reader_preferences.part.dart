part of '../novel_reader_state.dart';

extension _ReaderPreferences on NovelReaderState {
  Future<void> _loadReadingPreferences() async {
    try {
      final preferences = await _preferences.load(widget.novelId);
      if (!mounted || preferences == null) return;
      final imagePath = preferences.backgroundPath;
      final imageExists = imagePath != null && await File(imagePath).exists();
      if (!mounted) return;
      final savedPageColor = Color(preferences.pageColor);
      final savedTextColor = Color(preferences.textColor);
      _updateState(() {
        _englishFontSize = preferences.englishFontSize.clamp(8, 36).toDouble();
        _arabicFontSize = preferences.arabicFontSize.clamp(8, 36).toDouble();
        _playbackRate = preferences.playbackRate.clamp(.5, 2).toDouble();
        _wordPlaybackRate = preferences.wordPlaybackRate
            .clamp(.5, 2)
            .toDouble();
        _readerVoiceId = preferences.readerVoiceId == _femaleVoiceId
            ? _femaleVoiceId
            : _maleVoiceId;
        _syncLineOffset = _chapter == null
            ? 0
            : (preferences.chapterSyncOffsets[_chapter!.id] ?? 0);
        _pageColor = savedPageColor;
        _textColor =
            ThemeData.estimateBrightnessForColor(savedPageColor) ==
                ThemeData.estimateBrightnessForColor(savedTextColor)
            ? _foregroundFor(savedPageColor)
            : savedTextColor;
        _highlightColor = Color(preferences.highlightColor);
        _backgroundPath = imageExists ? imagePath : null;
        if (preferences.mixerOffsetX != null &&
            preferences.mixerOffsetY != null) {
          _mixerOffset = Offset(
            preferences.mixerOffsetX!,
            preferences.mixerOffsetY!,
          );
          _mixerPosition.value = _mixerOffset;
        }
      });
      if (_chapter != null) {
        await _restoreChapterAudio(_chapter!);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر استعادة إعدادات القراءة: $error')),
        );
      }
    }
  }

  void _schedulePreferencesSave() {
    _preferencesSaveTimer?.cancel();
    _preferencesSaveTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_saveReadingPreferences());
    });
  }

  void _moveMixer(Offset delta) {
    _mixerPosition.value += delta;
    _mixerOffset = _mixerPosition.value;
    _schedulePreferencesSave();
  }

  Future<void> _saveReadingPreferences() async {
    try {
      await _preferences.save(
        widget.novelId,
        NovelReaderPreferences(
          fontSize: _englishFontSize,
          englishFontSize: _englishFontSize,
          arabicFontSize: _arabicFontSize,
          playbackRate: _playbackRate,
          wordPlaybackRate: _wordPlaybackRate,
          readerVoiceId: _readerVoiceId,
          pageColor: _pageColor.toARGB32(),
          textColor: _textColor.toARGB32(),
          backgroundPath: _backgroundPath,
          chapterPositions: {
            if (_chapter != null) _chapter!.id: _position.inMilliseconds,
          },
          chapterSyncOffsets: {
            if (_chapter != null) _chapter!.id: _syncLineOffset,
          },
          mixerOffsetX: _mixerPosition.value.dx,
          mixerOffsetY: _mixerPosition.value.dy,
          highlightColor: _highlightColor.toARGB32(),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ إعدادات القراءة: $error')),
        );
      }
    }
  }

  Future<void> _loadNovel() async {
    try {
      final hasSubscription = await _repository.hasActiveSubscription();
      final novel = await _repository.fetchNovel(widget.novelId);
      if (!mounted) return;
      _updateState(() {
        _novel = novel;
        _hasSubscription = hasSubscription;
        _subscriptionRequired =
            novel != null && !novel.isFree && !hasSubscription;
        _chapter = _subscriptionRequired ? null : novel?.chapters.firstOrNull;
        _loading = false;
        _loadError = null;
      });
      if (_chapter != null) {
        unawaited(_loadAnnotations(_chapter!.id));
        // Try server pre-generated audio first for instant playback,
        // then fall back to on-device cached audio.
        final preGenLoaded = await _tryPreGeneratedAudio(_chapter!);
        if (!preGenLoaded && !_chapter!.hasRecordedAudioConfigured) {
          unawaited(_restoreChapterAudio(_chapter!));
        }
      }
      unawaited(_refreshSavedWordsCount());
    } catch (error) {
      if (!mounted) return;
      _updateState(() {
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _refreshSavedWordsCount() async {
    try {
      final count = await _repository.countSavedWords();
      if (mounted) _updateState(() => _savedWordsCount = count);
    } catch (_) {
      // The count is supplementary; the reader remains usable if unavailable.
    }
  }

  Future<void> _loadListeningUsage() async {
    try {
      final status = await _quota.loadStatus();
      if (mounted) {
        _updateState(() {
          _listeningSeconds = status.secondsUsed;
          _hasSubscription = status.hasSubscription;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر قراءة حد الاستماع اليومي: $error')),
        );
      }
    } finally {
      if (mounted) _updateState(() => _usageLoading = false);
    }
  }

  Future<void> _loadAnnotations(String chapterId) async {
    try {
      final highlights = await _repository.loadHighlights(chapterId);
      final notes = await _repository.loadNotes(chapterId);
      if (!mounted || _chapter?.id != chapterId) return;
      _updateState(() {
        _highlightedWords
          ..clear()
          ..addAll(highlights.map(_normalizeWord));
        _chapterNotes
          ..clear()
          ..addAll(notes);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحميل علامات القراءة المحفوظة')),
        );
      }
    }
  }
}
