part of '../novel_reader_state.dart';

class _SpeechChunk {
  const _SpeechChunk({
    required this.text,
    required this.sourceStart,
    required this.sourceEnd,
  });

  final String text;
  final int sourceStart;
  final int sourceEnd;
}

class _PreparedChapterSpeech {
  const _PreparedChapterSpeech({required this.chunks, required this.segments});

  final List<_SpeechChunk> chunks;
  final List<NovelSpeechAudio> segments;
}

extension _ReaderAudioState on NovelReaderState {
  /// Tries to load pre-generated server audio for the chapter. Returns `true`
  /// if successful and playback state has been fully initialized.
  Future<bool> _tryPreGeneratedAudio(NovelChapter chapter) async {
    if (!chapter.hasPreGeneratedAudio) return false;
    final novel = _novel;
    if (novel == null) return false;
    final voiceId = _readerVoiceId;
    final cacheId =
        'pregen_v3_${novel.id}_${chapter.id}_${chapter.audioRevision}';
    final audio = await _speech.downloadPreGeneratedAudio(
      audioUrl: chapter.audioUrl!,
      timestampsUrl: chapter.audioTimestampsUrl!,
      cacheId: cacheId,
      chapterText: chapter.text,
    );
    if (audio == null ||
        !mounted ||
        _chapter?.id != chapter.id ||
        _readerVoiceId != voiceId) {
      return false;
    }
    final preferences = await _preferences.load(widget.novelId);
    final savedMs = preferences?.chapterPositions[chapter.id] ?? 0;
    _syncLineOffset = preferences?.chapterSyncOffsets[chapter.id] ?? 0;
    _updateState(() {
      _speechAudio = audio;
      _speechSegments
        ..clear()
        ..add(audio);
      _speechSegmentOffsets
        ..clear()
        ..add(Duration.zero);
      _speechSegmentSourceOffsets
        ..clear()
        ..add(0);
      final chunk = _SpeechChunk(
        text: chapter.text,
        sourceStart: 0,
        sourceEnd: chapter.text.length,
      );
      _speechChunks = [chunk];
      _speechSegmentIndex = 0;
      _duration = audio.duration;
      _position = Duration(milliseconds: savedMs).compareTo(audio.duration) < 0
          ? Duration(milliseconds: savedMs)
          : Duration.zero;
      _positionNotifier.value = _position;
      _rememberPreparedChapter(
        novel: novel,
        chapter: chapter,
        voiceId: voiceId,
        chunks: [chunk],
        segments: [audio],
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _chapter?.id == chapter.id) _updatePosition(_position);
    });
    _startRemainingChaptersPrefetch();
    return true;
  }

  List<_SpeechChunk> _buildSpeechChunks(NovelChapter chapter) {
    final sentences = splitNovelSentences(chapter.text);
    final chunks = <_SpeechChunk>[];
    var searchFrom = 0;
    // Very small segments make TTS generation slower than playback and force
    // just_audio to reopen a file at every sentence. Group sentences into
    // larger chunks so the native model has enough runway to prepare the next
    // segment without audible gaps, while keeping the first audio quick and
    // timestamps exact. Larger chunks mean fewer segment transitions and more
    // time for the prefetch loop to stay ahead of playback.
    const maxSentences = 5;
    const maxCharacters = 900;
    for (var index = 0; index < sentences.length;) {
      final first = chapter.text.indexOf(sentences[index], searchFrom);
      if (first < 0) {
        index++;
        continue;
      }
      var last = first + sentences[index].length;
      var count = 1;
      while (index + count < sentences.length && count < maxSentences) {
        final next = chapter.text.indexOf(sentences[index + count], last);
        if (next < 0 ||
            next + sentences[index + count].length - first > maxCharacters) {
          break;
        }
        last = next + sentences[index + count].length;
        count++;
      }
      chunks.add(
        _SpeechChunk(
          text: chapter.text.substring(first, last),
          sourceStart: first,
          sourceEnd: last,
        ),
      );
      searchFrom = last;
      index += count;
    }
    return chunks.isEmpty
        ? [
            _SpeechChunk(
              text: chapter.text,
              sourceStart: 0,
              sourceEnd: chapter.text.length,
            ),
          ]
        : chunks;
  }

  Future<NovelSpeechAudio> _loadSpeechSegment(
    Novel novel,
    NovelChapter chapter,
    _SpeechChunk chunk,
    int index,
    String voiceId,
  ) async {
    final chunkHash = sha256
        .convert(utf8.encode(chunk.text))
        .toString()
        .substring(0, 10);
    final fileId =
        '${_chapterAudioCacheId(novel, chapter, voiceId)}_segment_${index}_$chunkHash';
    final cached = await _speech.loadCached(fileId);
    if (cached != null) return cached;
    return _speech.synthesize(chunk.text, fileId: fileId, voiceId: voiceId);
  }

  void _appendSpeechSegment(NovelSpeechAudio audio, _SpeechChunk chunk) {
    final offset = _speechSegments.isEmpty
        ? Duration.zero
        : _speechSegmentOffsets.last + _speechSegments.last.duration;
    _speechSegments.add(audio);
    _speechSegmentOffsets.add(offset);
    _speechSegmentSourceOffsets.add(chunk.sourceStart);
    final timestamps = [
      ...?_speechAudio?.wordTimestamps,
      for (final timestamp in audio.wordTimestamps)
        WordTimestamp(
          word: timestamp.word,
          start: chunk.sourceStart + timestamp.start,
          end: chunk.sourceStart + timestamp.end,
          startSeconds:
              offset.inMicroseconds / Duration.microsecondsPerSecond +
              timestamp.startSeconds,
          endSeconds:
              offset.inMicroseconds / Duration.microsecondsPerSecond +
              timestamp.endSeconds,
        ),
    ];
    _speechAudio = NovelSpeechAudio(
      path: audio.path,
      duration: offset + audio.duration,
      wordTimestamps: timestamps,
    );
    _duration = _speechAudio!.duration;
  }

  Future<void> _prefetchSpeechSegments() {
    final pending = _speechPrefetchFuture;
    if (pending != null) return pending;
    late Future<void> future;
    future = _prefetchSpeechSegmentsImpl().whenComplete(() {
      if (identical(_speechPrefetchFuture, future)) {
        _speechPrefetchFuture = null;
        // Continue warming the cache as long as there are segments left to
        // prepare. Each invocation prepares a batch of up to 4 segments
        // ahead of the current playback position, so the loop converges
        // quickly and never blocks the playing audio.
        if (mounted && _speechSegments.length < _speechChunks.length) {
          unawaited(_prefetchSpeechSegments());
        } else if (mounted && _speechSegments.length == _speechChunks.length) {
          final novel = _novel;
          final chapter = _chapter;
          if (novel != null && chapter != null) {
            _rememberPreparedChapter(
              novel: novel,
              chapter: chapter,
              voiceId: _readerVoiceId,
              chunks: _speechChunks,
              segments: _speechSegments,
            );
          }
          _startRemainingChaptersPrefetch();
        }
      }
    });
    _speechPrefetchFuture = future;
    return future;
  }

  void _startRemainingChaptersPrefetch() {
    if (_chaptersPrefetchFuture != null) return;
    final novel = _novel;
    final currentChapter = _chapter;
    if (novel == null || currentChapter == null || novel.chapters.length < 2) {
      return;
    }

    final voiceId = _readerVoiceId;
    final epoch = ++_chaptersPrefetchEpoch;
    final currentIndex = novel.chapters.indexWhere(
      (chapter) => chapter.id == currentChapter.id,
    );
    final remaining = <NovelChapter>[
      if (currentIndex >= 0) ...novel.chapters.skip(currentIndex + 1),
      ...novel.chapters.take(currentIndex < 0 ? 0 : currentIndex),
    ];

    late Future<void> future;
    future =
        _prefetchRemainingChapters(
          novel: novel,
          chapters: remaining,
          voiceId: voiceId,
          epoch: epoch,
        ).whenComplete(() {
          if (identical(_chaptersPrefetchFuture, future)) {
            _chaptersPrefetchFuture = null;
          }
        });
    _chaptersPrefetchFuture = future;
  }

  Future<void> _prefetchRemainingChapters({
    required Novel novel,
    required List<NovelChapter> chapters,
    required String voiceId,
    required int epoch,
  }) async {
    for (final chapter in chapters) {
      if (!mounted ||
          epoch != _chaptersPrefetchEpoch ||
          _novel?.id != novel.id ||
          _readerVoiceId != voiceId) {
        return;
      }

      // If chapter has pre-generated server audio, download and cache it directly.
      if (chapter.hasPreGeneratedAudio) {
        final cacheId =
            'pregen_v3_${novel.id}_${chapter.id}_${chapter.audioRevision}';
        try {
          final audio = await _speech.downloadPreGeneratedAudio(
            audioUrl: chapter.audioUrl!,
            timestampsUrl: chapter.audioTimestampsUrl!,
            cacheId: cacheId,
            chapterText: chapter.text,
          );
          if (audio != null &&
              mounted &&
              epoch == _chaptersPrefetchEpoch &&
              _readerVoiceId == voiceId) {
            _rememberPreparedChapter(
              novel: novel,
              chapter: chapter,
              voiceId: voiceId,
              chunks: [
                _SpeechChunk(
                  text: chapter.text,
                  sourceStart: 0,
                  sourceEnd: chapter.text.length,
                ),
              ],
              segments: [audio],
            );
          }
        } catch (_) {}
        continue;
      }

      // Chapters without server-provided audio are intentionally skipped.
      // On-device TTS/model generation was removed from the app.
    }
  }

  String _preparedChapterKey(
    Novel novel,
    NovelChapter chapter,
    String voiceId,
  ) => '${_chapterAudioCacheId(novel, chapter, voiceId)}::$voiceId';

  void _rememberPreparedChapter({
    required Novel novel,
    required NovelChapter chapter,
    required String voiceId,
    required List<_SpeechChunk> chunks,
    required List<NovelSpeechAudio> segments,
  }) {
    if (chunks.isEmpty || chunks.length != segments.length) return;
    _preparedChapters[_preparedChapterKey(
      novel,
      chapter,
      voiceId,
    )] = _PreparedChapterSpeech(
      chunks: List<_SpeechChunk>.unmodifiable(chunks),
      segments: List<NovelSpeechAudio>.unmodifiable(segments),
    );
  }

  Future<bool> _isSpeechSegmentCached(
    Novel novel,
    NovelChapter chapter,
    _SpeechChunk chunk,
    int index,
    String voiceId,
  ) async {
    final chunkHash = sha256
        .convert(utf8.encode(chunk.text))
        .toString()
        .substring(0, 10);
    final fileId =
        '${_chapterAudioCacheId(novel, chapter, voiceId)}_segment_${index}_$chunkHash';
    return (await _speech.loadCached(fileId)) != null;
  }

  Future<bool> _restorePreparedChapter(NovelChapter chapter) async {
    final novel = _novel;
    if (novel == null) return false;
    final voiceId = _readerVoiceId;
    final prepared =
        _preparedChapters[_preparedChapterKey(novel, chapter, voiceId)];
    if (prepared != null && prepared.segments.isNotEmpty) {
      final preferences = await _preferences.load(widget.novelId);
      if (!mounted || _chapter?.id != chapter.id || _readerVoiceId != voiceId) {
        return false;
      }
      final savedPosition = Duration(
        milliseconds: preferences?.chapterPositions[chapter.id] ?? 0,
      );
      _syncLineOffset = preferences?.chapterSyncOffsets[chapter.id] ?? 0;
      _updateState(() {
        _speechAudio = null;
        _speechSegments.clear();
        _speechSegmentOffsets.clear();
        _speechSegmentSourceOffsets.clear();
        _speechChunks = prepared.chunks;
        for (var index = 0; index < prepared.segments.length; index++) {
          _appendSpeechSegment(
            prepared.segments[index],
            prepared.chunks[index],
          );
        }
        _speechSegmentIndex = 0;
        _position = savedPosition < _duration ? savedPosition : Duration.zero;
        for (var index = 0; index < _speechSegments.length; index++) {
          final segmentEnd =
              _speechSegmentOffsets[index] + _speechSegments[index].duration;
          if (_position < segmentEnd) {
            _speechSegmentIndex = index;
            break;
          }
        }
        _positionNotifier.value = _position;
      });
      unawaited(_prefetchSpeechSegments());
      return true;
    }

    // Check if segments of this chapter were already prepared on disk by background prefetch
    final chunks = _buildSpeechChunks(chapter);
    if (chunks.isEmpty) return false;
    final cachedSegments = <NovelSpeechAudio>[];
    for (var i = 0; i < chunks.length; i++) {
      final isCached = await _isSpeechSegmentCached(
        novel,
        chapter,
        chunks[i],
        i,
        voiceId,
      );
      if (!isCached) break;
      final segment = await _loadSpeechSegment(
        novel,
        chapter,
        chunks[i],
        i,
        voiceId,
      );
      cachedSegments.add(segment);
    }

    final minRequired = math.min(2, chunks.length);
    if (cachedSegments.length >= minRequired) {
      if (!mounted || _chapter?.id != chapter.id || _readerVoiceId != voiceId) {
        return false;
      }
      final preferences = await _preferences.load(widget.novelId);
      final savedMs = preferences?.chapterPositions[chapter.id] ?? 0;
      _syncLineOffset = preferences?.chapterSyncOffsets[chapter.id] ?? 0;
      _updateState(() {
        _speechAudio = null;
        _speechSegments.clear();
        _speechSegmentOffsets.clear();
        _speechSegmentSourceOffsets.clear();
        _speechChunks = chunks;
        for (var index = 0; index < cachedSegments.length; index++) {
          _appendSpeechSegment(cachedSegments[index], chunks[index]);
        }
        _speechSegmentIndex = 0;
        _position = savedMs > 0 && savedMs < _duration.inMilliseconds
            ? Duration(milliseconds: savedMs)
            : Duration.zero;
        _positionNotifier.value = _position;
      });
      unawaited(_prefetchSpeechSegments());
      return true;
    }

    return false;
  }

  Future<void> _prefetchSpeechSegmentsImpl() async {
    final novel = _novel;
    final chapter = _chapter;
    if (novel == null || chapter == null) return;
    final voiceId = _readerVoiceId;
    // Prepare a batch of upcoming segments so playback never catches up with
    // the prefetch cursor. The old code prepared exactly one segment per cycle,
    // which was often slower than playback (especially at higher speeds).
    // Now we prepare up to _kPrefetchAhead segments beyond the current playback
    // position in a single pass, keeping the queue always full.
    const prefetchAhead = 4;
    final targetEnd = math.min(
      _speechSegmentIndex + prefetchAhead + 1,
      _speechChunks.length,
    );
    while (_speechSegments.length < targetEnd) {
      final index = _speechSegments.length;
      final audio = await _loadSpeechSegment(
        novel,
        chapter,
        _speechChunks[index],
        index,
        voiceId,
      );
      if (!mounted || _chapter?.id != chapter.id || _readerVoiceId != voiceId) {
        return;
      }
      _appendSpeechSegment(audio, _speechChunks[index]);
    }
    _updateState(() {});
  }

  Future<void> _handleNarrationComplete() async {
    if (_switchingChapter || _speechSegmentTransitioning) return;
    if (_speechSegmentIndex + 1 < _speechChunks.length) {
      if (_speechSegments.length <= _speechSegmentIndex + 1) {
        _updateState(() => _speechSegmentTransitioning = true);
      } else {
        _speechSegmentTransitioning = true;
      }
      try {
        while (_speechSegments.length <= _speechSegmentIndex + 1) {
          await _prefetchSpeechSegments();
          if (!mounted) return;
        }
        _speechSegmentIndex++;
        await _playCurrentSpeechSegment();
        // Keep one segment ahead of playback without delaying the transition.
        unawaited(_prefetchSpeechSegments());
      } finally {
        _speechSegmentTransitioning = false;
        if (mounted) _updateState(() {});
      }
      return;
    }
    _stopListeningTimer();
    unawaited(_syncBackgroundPlayback());
    final novel = _novel;
    final chapter = _chapter;
    final chapterIndex = novel?.chapters.indexWhere(
      (item) => item.id == chapter?.id,
    );
    final isLastChapter =
        novel != null &&
        chapterIndex != null &&
        chapterIndex >= 0 &&
        chapterIndex == novel.chapters.length - 1;
    if (!isLastChapter) _startNextChapterCountdown();
    if (mounted) {
      _updateState(() {
        _novelCompleted = isLastChapter;
        _activeWordStart = null;
        _activeWordEnd = null;
      });
    }
  }

  Future<void> _playCurrentSpeechSegment({Duration? position}) async {
    if (_speechSegments.isEmpty) return;
    final audio = _speechSegments[_speechSegmentIndex];
    await _player.setVolume(_narrationVolume);
    await _player.setSpeed(_playbackRate);
    await _player.setFilePath(audio.path);
    if (audio.sourceAudioStart > Duration.zero ||
        audio.sourceAudioEnd != null) {
      await _player.setClip(
        start: audio.sourceAudioStart,
        end: audio.sourceAudioEnd,
      );
    }
    if (position != null) await _player.seek(position);
    await _player.play();
  }

  Future<void> _restoreChapterAudio(NovelChapter chapter) async {
    final novel = _novel;
    if (novel == null) return;
    final voiceId = _readerVoiceId;
    final audio = await _speech.loadCached(
      _chapterAudioCacheId(novel, chapter, voiceId),
    );
    if (!mounted ||
        _chapter?.id != chapter.id ||
        _readerVoiceId != voiceId ||
        audio == null) {
      return;
    }
    final preferences = await _preferences.load(widget.novelId);
    final savedMs = preferences?.chapterPositions[chapter.id] ?? 0;
    _syncLineOffset = preferences?.chapterSyncOffsets[chapter.id] ?? 0;
    _updateState(() {
      _speechAudio = audio;
      _speechSegments
        ..clear()
        ..add(audio);
      _speechSegmentOffsets
        ..clear()
        ..add(Duration.zero);
      _speechSegmentSourceOffsets
        ..clear()
        ..add(0);
      _speechChunks = [
        _SpeechChunk(
          text: chapter.text,
          sourceStart: 0,
          sourceEnd: chapter.text.length,
        ),
      ];
      _speechSegmentIndex = 0;
      _duration = audio.duration;
      _position = Duration(milliseconds: savedMs).compareTo(audio.duration) < 0
          ? Duration(milliseconds: savedMs)
          : Duration.zero;
      _positionNotifier.value = _position;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _chapter?.id == chapter.id) _updatePosition(_position);
    });
  }

  String _chapterAudioCacheId(
    Novel novel,
    NovelChapter chapter,
    String voiceId,
  ) =>
      'v3_${novel.id}_${chapter.id}_'
      '${sha256.convert(utf8.encode(chapter.text)).toString().substring(0, 12)}'
      '${voiceId == _femaleVoiceId ? '' : '_$voiceId'}';

  String _wordAudioCacheId(String novelId, String normalizedWord) =>
      'word_cache_${novelId}_$normalizedWord'
      '${_readerVoiceId == _femaleVoiceId ? '' : '_$_readerVoiceId'}';

  Future<void> _setReaderVoice(String voiceId) async {
    if (_modelLoading ||
        _wordLoading ||
        (voiceId != _femaleVoiceId && voiceId != _maleVoiceId) ||
        voiceId == _readerVoiceId) {
      return;
    }

    final wasPlaying = _player.playing;
    _chaptersPrefetchEpoch++;
    await _wordPlayer.stop();
    if (wasPlaying) await _player.stop();
    if (!mounted) return;
    _updateState(() {
      _readerVoiceId = voiceId;
      _speechAudio = null;
      _speechSegments.clear();
      _speechSegmentOffsets.clear();
      _speechSegmentSourceOffsets.clear();
      _speechChunks = const [];
      _duration = Duration.zero;
    });
    await _saveReadingPreferences();
    if (wasPlaying && mounted) await _toggleAudio();
  }

  void _resyncHighlight() {
    _syncLineOffset = _syncLineOffset == 0 ? 1 : 0;
    _schedulePreferencesSave();
    if (_speechSegments.isNotEmpty) {
      final localPosition =
          _position - _speechSegmentOffsets[_speechSegmentIndex];
      _updatePosition(localPosition.isNegative ? Duration.zero : localPosition);
    }
    if (mounted) _updateState(() {});
  }

  WordTimestamp? _timestampForWord(int? start, int? end) {
    if (start == null || end == null || end <= start) return null;
    for (final timestamp
        in _speechAudio?.wordTimestamps ?? const <WordTimestamp>[]) {
      if (timestamp.start < end &&
          timestamp.end > start &&
          timestamp.startSeconds.isFinite &&
          timestamp.endSeconds.isFinite &&
          timestamp.startSeconds >= 0 &&
          timestamp.endSeconds > timestamp.startSeconds) {
        return timestamp;
      }
    }
    return null;
  }

  Future<void> _disposeAudioResources() async {
    await _player.dispose();
    await _wordPlayer.dispose();
    for (final player in _ambiencePlayers.values) {
      await player.dispose();
    }
    await _speech.dispose();
    _mixerPosition.dispose();
    _positionNotifier.dispose();
    _readerScrollController.dispose();
  }
}
