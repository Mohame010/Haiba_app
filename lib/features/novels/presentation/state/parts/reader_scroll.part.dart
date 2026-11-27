part of '../novel_reader_state.dart';

extension _ReaderScroll on NovelReaderState {
  void _updatePosition(Duration position) {
    if (_switchingChapter) return;
    // Native position events can arrive just after the audible frame. A small
    // lead keeps the visual word aligned with what the student is hearing.
    final globalPosition =
        (_speechSegmentOffsets.isNotEmpty
            ? _speechSegmentOffsets[_speechSegmentIndex]
            : Duration.zero) +
        position;
    final seconds =
        globalPosition.inMicroseconds / Duration.microsecondsPerSecond + .10;
    final timestamps = _speechAudio?.wordTimestamps ?? const <WordTimestamp>[];
    final active = _applySyncOffset(
      _timestampAt(timestamps, seconds),
      timestamps,
    );
    final wordChanged = _activeWordStart != active?.start;
    if (!mounted ||
        (_position == globalPosition &&
            _activeWordStart == active?.start &&
            _activeWordEnd == active?.end)) {
      return;
    }
    _position = globalPosition;
    _positionNotifier.value = globalPosition;
    _activeWordStart = active?.start;
    _activeWordEnd = active?.end;
    if (wordChanged && mounted) {
      _updateState(() {});
    }
    if (wordChanged && active != null) {
      _queueScrollToWord(active.start);
    }
    _schedulePreferencesSave();
  }

  WordTimestamp? _timestampAt(List<WordTimestamp> timestamps, double seconds) {
    if (timestamps.isEmpty) return null;
    var low = 0;
    var high = timestamps.length - 1;
    while (low <= high) {
      final middle = (low + high) >> 1;
      final timestamp = timestamps[middle];
      if (seconds < timestamp.startSeconds) {
        high = middle - 1;
      } else if (seconds >= timestamp.endSeconds) {
        low = middle + 1;
      } else {
        return timestamp;
      }
    }

    // A generated segment can have a very small silent gap between words.
    // Keep the highlight continuous across that gap instead of clearing it.
    final next = low < timestamps.length ? timestamps[low] : null;
    if (next != null && next.startSeconds - seconds <= .25) return next;
    final previous = high >= 0 ? timestamps[high] : null;
    if (previous != null && seconds - previous.endSeconds <= .25) {
      return previous;
    }
    return null;
  }

  WordTimestamp? _applySyncOffset(
    WordTimestamp? active,
    List<WordTimestamp> timestamps,
  ) {
    if (active == null || _syncLineOffset == 0 || _chapter == null) {
      return active;
    }
    final text = _chapter!.text;
    var lineStart = text.lastIndexOf('\n', math.max(0, active.start - 1)) + 1;
    var targetLine = lineStart;
    for (var line = 0; line < _syncLineOffset; line++) {
      final next = text.indexOf('\n', targetLine);
      if (next < 0) return active;
      targetLine = next + 1;
    }
    final targetEnd = text.indexOf('\n', targetLine);
    final lineEnd = targetEnd < 0 ? text.length : targetEnd;
    final currentLine = timestamps
        .where(
          (item) =>
              item.start >= lineStart &&
              item.start <
                  (text.indexOf('\n', lineStart) < 0
                      ? text.length
                      : text.indexOf('\n', lineStart)),
        )
        .toList();
    final targetLineTimestamps = timestamps
        .where((item) => item.start >= targetLine && item.start < lineEnd)
        .toList();
    if (currentLine.isEmpty || targetLineTimestamps.isEmpty) return active;
    final index = currentLine.indexWhere((item) => item.start == active.start);
    return targetLineTimestamps[math.min(
      math.max(index, 0),
      targetLineTimestamps.length - 1,
    )];
  }

  void _queueScrollToWord(int start) {
    _pendingAutoScrollStart = start;
    if (_autoScrollRunning) return;
    _autoScrollRunning = true;
    unawaited(_drainAutoScrollQueue());
  }

  Future<void> _drainAutoScrollQueue() async {
    while (mounted && _pendingAutoScrollStart != null) {
      final start = _pendingAutoScrollStart!;
      _pendingAutoScrollStart = null;
      await _scrollToWord(start);
    }
    _autoScrollRunning = false;
  }

  Future<void> _scrollToWord(int start) async {
    await WidgetsBinding.instance.endOfFrame;
    var wordContext = _wordKeys[start]?.currentContext;
    if (!mounted || !_readerScrollController.hasClients) return;
    if (wordContext == null) {
      final textLength = math.max(1, _chapter?.text.length ?? 1);
      final progress = (start / textLength).clamp(0.0, 1.0);
      final position = _readerScrollController.position;
      final estimated = position.maxScrollExtent * progress;
      await _readerScrollController.animateTo(
        estimated
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      await WidgetsBinding.instance.endOfFrame;
      wordContext = _wordKeys[start]?.currentContext;
    }
    if (!mounted || wordContext == null) return;
    final renderObject = wordContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final screenHeight = MediaQuery.sizeOf(context).height;
    final top = renderObject.localToGlobal(Offset.zero).dy;
    final bottom = top + renderObject.size.height;

    // Comfortable reading eye-level band (between top+80 and 52% of screen height).
    // Keeps active reading words centered and well above the bottom player controls!
    final comfortableTop = MediaQuery.paddingOf(context).top + 76.0;
    final comfortableBottom = screenHeight * 0.52;
    if (top >= comfortableTop && bottom <= comfortableBottom) return;

    final viewport = RenderAbstractViewport.of(renderObject);
    final scrollable = Scrollable.of(wordContext);
    // Align at 0.46 for ideal central eye-level reading
    final target = viewport
        .getOffsetToReveal(renderObject, 0.46)
        .offset
        .clamp(
          scrollable.position.minScrollExtent,
          scrollable.position.maxScrollExtent,
        )
        .toDouble();
    if ((target - scrollable.position.pixels).abs() < 10) return;
    await scrollable.position.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }
}
