import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/services/tts_cache_service.dart';
import '../../../core/helpers/app_logger.dart';
import '../../../core/theme/app_colors.dart';

import '../../data/mediapipe_novel_audio_service.dart';
import '../../data/ambient_crossfade_player.dart';
import '../../data/novel_ambience_service.dart';
import '../../data/novel_listening_quota.dart';
import '../../../core/services/screen_protection_service.dart';
import '../../data/novel_reader_preferences.dart';
import '../../data/novels_repository.dart';
import '../../domain/novel_entities.dart';
import '../../domain/novel_audio_timestamps.dart';
import '../../domain/novel_word_normalizer.dart';
import '../../domain/novel_text_alignment.dart';
import '../widgets/novel_subscription_sheet.dart';
import '../widgets/novel_saved_words_screen.dart';
import '../widgets/novel_reader_status_widgets.dart';
import '../widgets/novel_reader_text_view.dart';
import '../widgets/reader_color_dialog.dart';

import '../screens/novel_reader_screen.dart';

import '../widgets/novel_reader_page_layout.dart';
import '../widgets/novel_reader_player_panel.dart';
import '../widgets/novel_video_backdrop.dart';
part 'parts/reader_preferences.part.dart';
part 'parts/reader_scroll.part.dart';
part 'parts/reader_audio_state.part.dart';
part 'parts/reader_listening.part.dart';
part 'parts/reader_ambience.part.dart';
part 'parts/reader_playback.part.dart';
part 'parts/reader_word_audio.part.dart';
part 'parts/reader_annotations.part.dart';
part 'parts/reader_word_cards.part.dart';
part 'parts/reader_navigation.part.dart';
part 'parts/reader_content.part.dart';
part 'parts/reader_ambience_widgets.part.dart';
part 'parts/reader_player_widget.part.dart';
part 'parts/reader_player_settings.part.dart';
part 'parts/reader_settings.part.dart';

const _playbackChannel = MethodChannel('q360education/novel_playback');
const _femaleVoiceId = 'freya';
const _maleVoiceId = 'lucas';
const _narrationVolume = 1.0;
const _maxAmbienceVolume = .28;

class NovelReaderState extends State<NovelReaderScreen>
    with WidgetsBindingObserver {
  final _repository = NovelsRepository();
  final _player = just_audio.AudioPlayer();
  // Use the same just_audio backend for isolated words as for narration.
  // audioplayers' completion stream can miss the terminal event on some
  // Android audio sessions, leaving the word card's spinner stuck forever.
  final _wordPlayer = just_audio.AudioPlayer();
  final Map<NovelAmbientSound, AmbientCrossfadePlayer> _ambiencePlayers = {};
  final _speech = MediaPipeNovelAudioService();
  final _ambience = NovelAmbienceService();
  final _preferences = NovelReaderPreferencesStore();
  final _quota = NovelListeningQuota();
  final Set<String> _highlightedWords = {};
  final Map<String, String> _chapterNotes = {};
  final _readerScrollController = ScrollController();
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(
    Duration.zero,
  );
  final Map<int, GlobalKey> _wordKeys = {};
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Map<String, _PreparedChapterSpeech> _preparedChapters = {};

  Novel? _novel;
  NovelChapter? _chapter;
  NovelSpeechAudio? _speechAudio;
  final List<NovelSpeechAudio> _speechSegments = [];
  final List<Duration> _speechSegmentOffsets = [];
  final List<int> _speechSegmentSourceOffsets = [];
  List<_SpeechChunk> _speechChunks = const [];
  int _speechSegmentIndex = 0;
  bool _speechSegmentTransitioning = false;
  Future<void>? _speechPrefetchFuture;
  Future<void>? _chaptersPrefetchFuture;
  int _chaptersPrefetchEpoch = 0;
  bool _loading = true;
  bool _modelLoading = false;
  bool _usageLoading = true;
  bool _hasSubscription = false;
  bool _subscriptionRequired = false;
  bool _quotaWriteInProgress = false;
  bool _wordLoading = false;
  bool _readingFocusMode = false;
  bool _notesFloatingVisible = false;
  bool _switchingChapter = false;
  bool _novelCompleted = false;
  String _readerVoiceId = _maleVoiceId;
  String? _loadError;
  String? _backgroundPath;
  bool _showVideo = true;
  double? _downloadProgress;
  double _englishFontSize = 19;
  double _arabicFontSize = 18;
  double _playbackRate = 1;
  double _wordPlaybackRate = 1;
  Color _pageColor = AppColors.background;
  Color _textColor = AppColors.textPrimary;
  Color _highlightColor = const Color(0xffffe28a);
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  int _listeningSeconds = 0;
  int _pendingListeningSeconds = 0;
  int _savedWordsCount = 0;
  int _syncLineOffset = 0;
  int _subscriptionCheckCountdown = 30;
  int? _activeWordStart;
  int? _activeWordEnd;
  int? _pendingAutoScrollStart;
  bool _autoScrollRunning = false;
  final Set<NovelAmbientSound> _activeAmbienceSounds = {};
  final Set<NovelAmbientSound> _downloadingAmbienceSounds = {};
  final Map<NovelAmbientSound, double> _ambienceVolumes = {
    for (final sound in NovelAmbientSound.values) sound: .35,
  };
  bool _ambiencePanelVisible = false;
  Timer? _listeningTimer;
  Timer? _preferencesSaveTimer;
  Timer? _chapterCountdownTimer;
  int _chapterCountdown = 0;
  Offset _mixerOffset = const Offset(16, 96);
  final ValueNotifier<Offset> _mixerPosition = ValueNotifier(
    const Offset(16, 96),
  );

  void _updateState(VoidCallback update) => setState(update);

  @override
  void initState() {
    super.initState();
    ScreenProtectionService.release();
    WidgetsBinding.instance.addObserver(this);
    _loadNovel();
    _loadListeningUsage();
    _loadReadingPreferences();
    _subscriptions.add(_player.positionStream.listen(_updatePosition));
    _subscriptions.add(
      _player.durationStream.listen((duration) {
        if (duration == null) return;
        if (mounted && _speechSegments.length <= 1) {
          setState(() => _duration = duration);
        }
      }),
    );
    _subscriptions.add(
      _player.playerStateStream.listen(
        (state) => _onPlayerStateChanged(
          state.playing ? PlayerState.playing : PlayerState.paused,
        ),
      ),
    );
    _subscriptions.add(
      _player.processingStateStream
          .distinct()
          .where((state) => state == just_audio.ProcessingState.completed)
          .listen((_) => unawaited(_handleNarrationComplete())),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_flushListeningSeconds());
    }
  }

  @override
  void dispose() {
    ScreenProtectionService.release();
    _chaptersPrefetchEpoch++;
    WidgetsBinding.instance.removeObserver(this);
    _stopListeningTimer();
    _chapterCountdownTimer?.cancel();
    unawaited(_saveReadingPreferences());
    _preferencesSaveTimer?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_setBackgroundPlayback(false));
    unawaited(_disposeAudioResources());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const NovelReaderLoadingView();
    if (_subscriptionRequired) {
      return NovelReaderSubscriptionView(
        onShowPaywall: () =>
            unawaited(_showPaywall('اشترك لفتح هذه الرواية والاستماع إليها.')),
      );
    }

    final novel = _novel;
    final chapter = _chapter;
    if (novel == null || chapter == null) {
      return NovelReaderUnavailableView(
        error: _loadError,
        onRetry: () {
          setState(() {
            _loading = true;
            _loadError = null;
          });
          unawaited(_loadNovel());
        },
      );
    }

    final chapterIndex = novel.chapters.indexWhere(
      (item) => item.id == chapter.id,
    );
    final nextChapter =
        chapterIndex >= 0 && chapterIndex + 1 < novel.chapters.length
        ? novel.chapters[chapterIndex + 1]
        : null;

    return NovelReaderPageLayout(
      novel: novel,
      chapter: chapter,
      pageColor: _pageColor,
      foregroundColor: _foregroundFor(_pageColor),
      backgroundPath: _backgroundPath,
      readingFocusMode: _readingFocusMode,
      videoBackdrop: _buildVideoBackdrop(chapter, novel),
      preparationMessage:
          !_player.playing && (_modelLoading || _speechSegmentTransitioning)
          ? (_speechSegmentTransitioning
                ? 'جارٍ تجهيز نطق الفقرة التالية...'
                : 'جارٍ تجهيز نطق الرواية...')
          : null,
      reader: _buildReader(chapter),
      player: _buildPlayer(chapter),
      ambientMixer: _buildAmbientMixerOverlay(),
      floatingNotes: _notesFloatingVisible ? _buildFloatingNotes() : null,
      chapterCountdown: _chapterCountdown,
      nextChapterTitle: nextChapter?.title,
      onNextChapter: nextChapter == null
          ? null
          : () => unawaited(_selectChapter(nextChapter)),
      onSettings: _showReadingSettings,
      onSelectChapter: (selected) => unawaited(_selectChapter(selected)),
      onCancelCountdown: _cancelNextChapterCountdown,
      onExitFocusMode: _showReadingChrome,
      onSavedWords: _showSavedWords,
      savedWordsCount: _savedWordsCount,
      showVideo: _showVideo,
      onToggleVideo: () => _updateState(() => _showVideo = !_showVideo),
    );
  }

  Widget? _buildVideoBackdrop(NovelChapter chapter, Novel novel) {
    if (!_showVideo) return null;

    final segments = chapter.videoSegments.isNotEmpty
        ? chapter.videoSegments
        : novel.videoSegments;

    if (segments.isEmpty) return null;

    return StreamBuilder<bool>(
      stream: _player.playingStream,
      initialData: _player.playing,
      builder: (context, playingSnap) {
        final isPlaying = playingSnap.data ?? false;
        return ValueListenableBuilder<Duration>(
          valueListenable: _positionNotifier,
          builder: (context, pos, _) {
            final sec = pos.inMilliseconds / 1000.0;
            return NovelVideoBackdrop(
              currentSeconds: sec,
              isPlaying: isPlaying,
              videoSegments: segments,
              pageColor: _pageColor,
              fallbackCoverUrl: novel.coverUrl,
            );
          },
        );
      },
    );
  }
}
