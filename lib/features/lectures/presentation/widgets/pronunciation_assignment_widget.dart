import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/services/tts_cache_service.dart';
import '../../data/services/pronunciation_assignment_service.dart';
import '../../data/services/pronunciation_recorder.dart';

class PronunciationAssignmentWidget extends StatefulWidget {
  const PronunciationAssignmentWidget({super.key, required this.lectureId});

  final String lectureId;

  @override
  State<PronunciationAssignmentWidget> createState() =>
      _PronunciationAssignmentWidgetState();
}

class _PronunciationAssignmentWidgetState
    extends State<PronunciationAssignmentWidget>
    with SingleTickerProviderStateMixin {
  final PronunciationAssignmentService _service =
      PronunciationAssignmentService();
  final PronunciationRecorder _recorder = PronunciationRecorder();
  final AudioPlayer _player = AudioPlayer();
  final Map<String, String> _recordings = {};
  final Map<String, Map<String, dynamic>> _submissions = {};
  final Map<String, int> _recordingDurations = {};
  final Map<String, int> _recordingSizes = {};
  final List<double> _waveform = [];

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  List<Map<String, dynamic>> _words = const [];
  StreamSubscription<void>? _playerCompleteSubscription;
  Timer? _recordingTimer;
  Stopwatch? _stopwatch;
  String? _recordingWordId;
  String? _playingWordId;
  String? _playingTargetWord;
  just_audio.AudioPlayer? _ttsPlayer;
  bool _loading = true;
  bool _submitting = false;
  bool _stoppingRecording = false;
  bool _pollingAmplitude = false;
  bool _expanded = false;
  String? _error;
  int _elapsedMilliseconds = 0;
  int _uploadIndex = 0;
  int _uploadCount = 0;

  @override
  void initState() {
    super.initState();
    _playerCompleteSubscription = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingWordId = null);
    });
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final words = await _service.loadWords(widget.lectureId);
      final submissions = await _service.loadStudentSubmissions([
        for (final word in words) word['id'] as String,
      ]);
      if (!mounted) return;
      setState(() {
        _words = words;
        _submissions
          ..clear()
          ..addAll(submissions);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _startRecording(Map<String, dynamic> word) async {
    if (_recordingWordId != null || _stoppingRecording || _submitting) return;
    final wordId = word['id'] as String;
    final durationSeconds =
        (word['max_duration_seconds'] as num?)?.toInt() ?? 5;
    String? path;
    try {
      final granted = await _recorder.requestPermission();
      if (!mounted) return;
      if (!granted) {
        _showMessage('اسمح باستخدام الميكروفون لتسجيل نطقك.');
        return;
      }
      final directory = await getTemporaryDirectory();
      path =
          '${directory.path}${Platform.pathSeparator}'
          'pronunciation_${wordId}_${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _player.stop();
      await _recorder.start(path: path, maxDurationSeconds: durationSeconds);
      if (!mounted) {
        final recording = await _recorder.stop();
        if (recording != null && await File(recording.path).exists()) {
          await File(recording.path).delete();
        }
        return;
      }
      setState(() {
        _recordingWordId = wordId;
        _playingWordId = null;
        _elapsedMilliseconds = 0;
        _waveform.clear();
      });
      _stopwatch = Stopwatch()..start();
      _pulseController.repeat(reverse: true);
      _recordingTimer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _updateRecording(durationSeconds),
      );
    } catch (error) {
      if (path != null && await File(path).exists()) await File(path).delete();
      if (mounted) _showMessage('تعذر بدء التسجيل: $error');
    }
  }

  Future<void> _updateRecording(int maxDurationSeconds) async {
    if (!mounted || _recordingWordId == null) return;
    final elapsed = _stopwatch?.elapsedMilliseconds ?? 0;
    if (elapsed >= maxDurationSeconds * 1000) {
      await _stopRecording(reachedLimit: true);
      return;
    }
    setState(() => _elapsedMilliseconds = elapsed);
    if (_pollingAmplitude) return;
    _pollingAmplitude = true;
    try {
      final amplitude = await _recorder.amplitude();
      if (mounted && _recordingWordId != null) {
        setState(() {
          _waveform.add(amplitude.clamp(0, 1));
          if (_waveform.length > 32) _waveform.removeAt(0);
        });
      }
    } catch (error, stackTrace) {
      developer.log(
        'Could not read recording amplitude',
        name: 'Q360.Pronunciation',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _pollingAmplitude = false;
    }
  }

  Future<void> _stopRecording({bool reachedLimit = false}) async {
    final wordId = _recordingWordId;
    if (wordId == null || _stoppingRecording) return;
    _stoppingRecording = true;
    _pulseController.stop();
    _pulseController.reset();
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _stopwatch?.stop();
    setState(() => _recordingWordId = null);

    try {
      final recorded = await _recorder.stop();
      if (recorded == null || recorded.durationMs < 250) {
        if (recorded != null && await File(recorded.path).exists()) {
          await File(recorded.path).delete();
        }
        if (mounted) _showMessage('التسجيل قصير جدًا. جرّب مرة أخرى.');
        return;
      }
      if (recorded.fileSizeBytes >
          PronunciationAssignmentService.maxFileSizeBytes) {
        await File(recorded.path).delete();
        if (mounted) {
          _showMessage(
            'حجم التسجيل تجاوز 24 كيلوبايت. اختصر نطق الكلمة وحاول مرة أخرى.',
          );
        }
        return;
      }

      final previous = _recordings[wordId];
      if (previous != null && await File(previous).exists()) {
        await File(previous).delete();
      }
      if (!mounted) return;
      final wordDurationSeconds =
          (_words.firstWhere(
                    (word) => word['id'] == wordId,
                  )['max_duration_seconds']
                  as num?)
              ?.toInt() ??
          10;
      final durationMs = recorded.durationMs
          .clamp(250, wordDurationSeconds * 1000)
          .toInt();
      setState(() {
        _recordings[wordId] = recorded.path;
        _recordingDurations[wordId] = durationMs;
        _recordingSizes[wordId] = recorded.fileSizeBytes;
        _elapsedMilliseconds = durationMs;
      });
      if (reachedLimit) {
        _showMessage('انتهى الوقت المحدد وأصبح التسجيل جاهزًا.');
      }
    } catch (error) {
      if (mounted) _showMessage('تعذر حفظ التسجيل: $error');
    } finally {
      _stoppingRecording = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _playRecording(Map<String, dynamic> word) async {
    final wordId = word['id'] as String;
    if (_playingWordId == wordId) {
      await _player.stop();
      if (mounted) setState(() => _playingWordId = null);
      return;
    }

    try {
      await _player.stop();
      final localPath = _recordings[wordId];
      if (localPath != null) {
        await _player.play(DeviceFileSource(localPath));
      } else {
        final submission = _submissions[wordId];
        if (submission == null) return;
        final url = await _service.createStudentAudioUrl(
          submission['audio_path'] as String,
        );
        await _player.play(UrlSource(url));
      }
      if (mounted) setState(() => _playingWordId = wordId);
    } catch (error) {
      if (mounted) _showMessage('تعذر تشغيل التسجيل: $error');
    }
  }

  Future<void> _submitRecordings() async {
    if (_submitting || _recordings.isEmpty) return;
    setState(() {
      _submitting = true;
      _uploadIndex = 0;
      _uploadCount = _recordings.length;
    });
    try {
      final pending = Map<String, String>.from(_recordings);
      var index = 0;
      for (final entry in pending.entries) {
        final previousPath = _submissions[entry.key]?['audio_path'] as String?;
        final wordId = entry.key;
        final row = await _service.submitRecording(
          lectureId: widget.lectureId,
          wordId: wordId,
          localPath: entry.value,
          durationMs: _recordingDurations[wordId]!,
          previousAudioPath: previousPath,
        );
        if (await File(entry.value).exists()) await File(entry.value).delete();
        if (!mounted) return;
        setState(() {
          _submissions[wordId] = row;
          _recordings.remove(wordId);
          _recordingDurations.remove(wordId);
          _recordingSizes.remove(wordId);
          _uploadIndex = ++index;
        });
      }
      if (mounted) _showMessage('تم تسليم تسجيلات النطق للمدرس.');
    } catch (error) {
      if (mounted) _showMessage('تعذر تسليم التسجيلات: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  int get _completedWordCount => _words.where((word) {
    final id = word['id'] as String;
    return _recordings.containsKey(id) || _submissions.containsKey(id);
  }).length;

  bool get _allWordsRecorded =>
      _words.isNotEmpty && _completedWordCount == _words.length;

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDuration(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final remainder = ((milliseconds % 1000) ~/ 100).toString();
    return '$seconds.$remainder ث';
  }

  Future<void> _cleanup() async {
    _recordingTimer?.cancel();
    if (_recordingWordId != null) {
      try {
        final recorded = await _recorder.stop();
        if (recorded != null && await File(recorded.path).exists()) {
          await File(recorded.path).delete();
        }
      } catch (error, stackTrace) {
        developer.log(
          'Could not stop active pronunciation recording during cleanup',
          name: 'Q360.Pronunciation',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    for (final path in _recordings.values) {
      try {
        if (await File(path).exists()) await File(path).delete();
      } catch (error, stackTrace) {
        developer.log(
          'Could not remove temporary pronunciation audio',
          name: 'Q360.Pronunciation',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    await _player.dispose();
    await _ttsPlayer?.dispose();
  }

  Future<void> _pronounceTargetWord(String rawWord) async {
    final clean = rawWord.trim();
    if (clean.isEmpty) return;
    if (_playingTargetWord == clean) {
      await _ttsPlayer?.stop();
      if (mounted) setState(() => _playingTargetWord = null);
      return;
    }
    try {
      await _player.stop();
      if (mounted) setState(() => _playingWordId = null);
      _ttsPlayer ??= just_audio.AudioPlayer();
      setState(() => _playingTargetWord = clean);
      await TtsCacheService.instance.pronounce(_ttsPlayer!, clean);
    } catch (_) {
    } finally {
      if (mounted && _playingTargetWord == clean) {
        setState(() => _playingTargetWord = null);
      }
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _stopwatch?.stop();
    _playerCompleteSubscription?.cancel();
    _pulseController.dispose();
    unawaited(_cleanup());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return _PronunciationError(message: _error!, onRetry: _load);
    }
    if (_words.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(top: 18.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE7E9F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: const Icon(
                  Icons.record_voice_over_rounded,
                  color: Color(0xFF6D28D9),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سجّل نطق الكلمات',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E1B4B),
                        fontFamily: 'IBM',
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      '$_completedWordCount من ${_words.length} كلمة جاهزة',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: const Color(0xFF6B7280),
                        fontFamily: 'IBM',
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _expanded ? 'طي تدريب النطق' : 'عرض تدريب النطق',
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: AnimatedRotation(
                  turns: _expanded ? .5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF6D28D9),
                  ),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: !_expanded
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 14.h),
                      for (var index = 0; index < _words.length; index++) ...[
                        if (index > 0) SizedBox(height: 10.h),
                        _buildWordCard(_words[index], index + 1),
                      ],
                      SizedBox(height: 16.h),
                      SizedBox(
                        height: 50.h,
                        child: FilledButton.icon(
                          onPressed:
                              _allWordsRecorded &&
                                  _recordings.isNotEmpty &&
                                  !_submitting
                              ? _submitRecordings
                              : null,
                          icon: _submitting
                              ? SizedBox.square(
                                  dimension: 18.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                          label: Text(
                            _submitting
                                ? 'جارٍ التسليم ($_uploadIndex/$_uploadCount)'
                                : _allWordsRecorded
                                ? _recordings.isEmpty
                                      ? 'تم تسليم جميع الكلمات'
                                      : 'تسليم النطق'
                                : 'سجّل باقي الكلمات أولًا',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontFamily: 'IBM',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCard(Map<String, dynamic> word, int number) {
    final wordId = word['id'] as String;
    final maxSeconds = (word['max_duration_seconds'] as num?)?.toInt() ?? 5;
    final isRecording = _recordingWordId == wordId;
    final localRecording = _recordings[wordId];
    final submission = _submissions[wordId];
    final hasRecording = localRecording != null || submission != null;
    final isPlaying = _playingWordId == wordId;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: isRecording ? const Color(0xFFFFF1F2) : Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: isRecording
              ? const Color(0xFFF43F5E)
              : hasRecording
              ? const Color(0xFFBBF7D0)
              : const Color(0xFFE2E8F0),
          width: isRecording ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isRecording
                ? const Color(0xFFF43F5E).withValues(alpha: 0.12)
                : Colors.black.withAlpha(5),
            blurRadius: isRecording ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isRecording
                      ? const Color(0xFFFFE4E6)
                      : const Color(0xFFEDE9FE),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: isRecording
                        ? const Color(0xFFE11D48)
                        : const Color(0xFF6D28D9),
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'IBM',
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(start: 8.w),
                    child: Text(
                      word['word'] as String? ?? '',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 16.5.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E1B4B),
                        fontFamily: 'IBM',
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'استمع للنطق الصحيح',
                onPressed: () =>
                    _pronounceTargetWord(word['word'] as String? ?? ''),
                icon: Icon(
                  _playingTargetWord == (word['word'] as String? ?? '')
                      ? Icons.volume_up_rounded
                      : Icons.volume_down_rounded,
                  color: const Color(0xFF6D28D9),
                  size: 24.w,
                ),
              ),
              if (hasRecording)
                IconButton(
                  tooltip: isPlaying ? 'إيقاف التشغيل' : 'استمع للتسجيل',
                  onPressed: () => _playRecording(word),
                  icon: Icon(
                    isPlaying
                        ? Icons.stop_circle_rounded
                        : Icons.play_circle_fill_rounded,
                    color: const Color(0xFF059669),
                    size: 30.w,
                  ),
                ),
              SizedBox(width: 4.w),
              _buildMicButton(
                isRecording: isRecording,
                onPressed:
                    _submitting ||
                        _stoppingRecording ||
                        (_recordingWordId != null && !isRecording)
                    ? null
                    : () => isRecording
                          ? _stopRecording()
                          : _startRecording(word),
              ),
            ],
          ),
          if (isRecording) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFFDA4AF)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8.w,
                        height: 8.w,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'جارٍ تسجيل نطقك...',
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF991B1B),
                          fontFamily: 'IBM',
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_formatDuration(_elapsedMilliseconds)} / $maxSeconds ث',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFB91C1C),
                          fontFamily: 'IBM',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  _buildWaveform(),
                ],
              ),
            ),
          ] else
            Padding(
              padding: EdgeInsetsDirectional.only(start: 42.w, top: 4.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      localRecording != null
                          ? 'جاهز للتسليم'
                          : submission != null
                          ? 'تم التسليم للمدرس'
                          : 'اضغط على الميكروفون وقل الكلمة بوضوح',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: hasRecording
                            ? const Color(0xFF047857)
                            : const Color(0xFF6B7280),
                        fontFamily: 'IBM',
                        fontWeight: hasRecording
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    'حتى $maxSeconds ث',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: const Color(0xFF9CA3AF),
                      fontFamily: 'IBM',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMicButton({
    required bool isRecording,
    required VoidCallback? onPressed,
  }) {
    if (!isRecording) {
      return SizedBox(
        width: 44.w,
        height: 44.w,
        child: IconButton.filled(
          tooltip: 'تسجيل النطق',
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
          icon: const Icon(Icons.mic_rounded, size: 22),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.1);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFFDC2626,
                  ).withValues(alpha: 0.3 + 0.35 * _pulseController.value),
                  blurRadius: 12 + 8 * _pulseController.value,
                  spreadRadius: 2 + 3 * _pulseController.value,
                ),
              ],
            ),
            child: IconButton.filled(
              tooltip: 'إنهاء التسجيل',
              onPressed: onPressed,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.stop_rounded, size: 22),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWaveform() => SizedBox(
    height: 34.h,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(32, (index) {
        final offset = 32 - _waveform.length;
        final sampleIndex = index - offset;
        final amplitude = sampleIndex >= 0 && sampleIndex < _waveform.length
            ? _waveform[sampleIndex]
            : .08;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 1.w),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              height: (6 + amplitude * 26).h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFFDC2626),
                    const Color(
                      0xFFF43F5E,
                    ).withValues(alpha: .5 + amplitude * .5),
                  ],
                ),
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
          ),
        );
      }),
    ),
  );
}

class _PronunciationError extends StatelessWidget {
  const _PronunciationError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(top: 18.h),
    padding: EdgeInsets.all(16.w),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Column(
      children: [
        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
        SizedBox(height: 8.h),
        Text(
          'تعذر تحميل تدريب النطق: $message',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.sp,
            height: 1.4,
            color: const Color(0xFF6B7280),
            fontFamily: 'IBM',
          ),
        ),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('إعادة المحاولة'),
        ),
      ],
    ),
  );
}
