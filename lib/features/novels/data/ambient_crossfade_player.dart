import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';

/// Loops a local ambience track by overlapping its end with its beginning.
///
/// Two players alternate roles and use an equal-power crossfade, avoiding the
/// audible cut produced by [ReleaseMode.loop] at the file boundary.
class AmbientCrossfadePlayer {
  AmbientCrossfadePlayer({
    this.crossfadeDuration = const Duration(milliseconds: 1800),
  });

  final Duration crossfadeDuration;
  final List<AudioPlayer> _players = [AudioPlayer(), AudioPlayer()];
  Timer? _transitionTimer;
  int _currentIndex = 0;
  int _generation = 0;
  double _volume = .25;
  String? _path;
  Duration _trackDuration = Duration.zero;
  bool _playing = false;
  bool _disposed = false;

  Future<void> play(String path, {required double volume}) async {
    _checkNotDisposed();
    await stop();
    final generation = ++_generation;
    _path = path;
    _volume = volume.clamp(0, 1).toDouble();
    _currentIndex = 0;
    _playing = true;

    final player = _players[_currentIndex];
    final durationReady = player.onDurationChanged.firstWhere(
      (duration) => duration > Duration.zero,
    );
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setVolume(_volume);
    await player.play(DeviceFileSource(path), ctx: _audioContext);
    _trackDuration = await durationReady.timeout(
      const Duration(seconds: 4),
      onTimeout: () async => await player.getDuration() ?? Duration.zero,
    );
    if (!_isCurrent(generation)) return;
    if (_trackDuration <= Duration.zero) {
      await stop();
      throw StateError('تعذر تحديد مدة ملف صوت الخلفية.');
    }
    _scheduleTransition(generation);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0, 1).toDouble();
    if (_playing) await _players[_currentIndex].setVolume(_volume);
  }

  Future<void> stop() async {
    _playing = false;
    _generation++;
    _transitionTimer?.cancel();
    _transitionTimer = null;
    await Future.wait(_players.map((player) => player.stop()));
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _playing = false;
    _generation++;
    _transitionTimer?.cancel();
    await Future.wait(_players.map((player) => player.dispose()));
  }

  void _scheduleTransition(int generation, {Duration elapsed = Duration.zero}) {
    _transitionTimer?.cancel();
    final fade = _effectiveFadeDuration;
    final delay = _trackDuration - fade - elapsed;
    _transitionTimer = Timer(
      delay > Duration.zero ? delay : Duration.zero,
      () => unawaited(_crossfade(generation, fade)),
    );
  }

  Duration get _effectiveFadeDuration {
    final maximum = Duration(milliseconds: _trackDuration.inMilliseconds ~/ 3);
    return crossfadeDuration < maximum ? crossfadeDuration : maximum;
  }

  Future<void> _crossfade(int generation, Duration fadeDuration) async {
    if (!_isCurrent(generation) || _path == null) return;
    final outgoing = _players[_currentIndex];
    final incomingIndex = 1 - _currentIndex;
    final incoming = _players[incomingIndex];
    await incoming.setReleaseMode(ReleaseMode.stop);
    await incoming.setVolume(0);
    await incoming.play(DeviceFileSource(_path!), ctx: _audioContext);
    if (!_isCurrent(generation)) {
      await incoming.stop();
      return;
    }

    const steps = 20;
    final stepDuration = Duration(
      microseconds: math.max(1, fadeDuration.inMicroseconds ~/ steps),
    );
    for (var step = 1; step <= steps; step++) {
      await Future<void>.delayed(stepDuration);
      if (!_isCurrent(generation)) return;
      final progress = step / steps;
      final outgoingVolume = _volume * math.cos(progress * math.pi / 2);
      final incomingVolume = _volume * math.sin(progress * math.pi / 2);
      await Future.wait([
        outgoing.setVolume(outgoingVolume),
        incoming.setVolume(incomingVolume),
      ]);
    }

    if (!_isCurrent(generation)) return;
    await outgoing.stop();
    _currentIndex = incomingIndex;
    await incoming.setVolume(_volume);
    // The incoming player has already advanced by the fade duration while the
    // two copies overlapped, so account for that when scheduling its ending.
    _scheduleTransition(generation, elapsed: fadeDuration);
  }

  bool _isCurrent(int generation) =>
      !_disposed && _playing && generation == _generation;

  void _checkNotDisposed() {
    if (_disposed) throw StateError('مشغّل أصوات الخلفية مغلق.');
  }

  AudioContext get _audioContext => AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
    stayAwake: true,
  ).build();
}
