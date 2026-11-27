part of '../novel_reader_state.dart';

extension _ReaderAmbience on NovelReaderState {
  Future<void> _setBackgroundPlayback(bool playing) async {
    if (!Platform.isAndroid) return;
    try {
      await _playbackChannel.invokeMethod<void>(
        playing ? 'start' : 'stop',
        playing
            ? {
                'title': _player.playing
                    ? _chapter?.title ?? 'رواية'
                    : 'أصوات خلفية للمذاكرة',
              }
            : null,
      );
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تفعيل التشغيل في الخلفية')),
        );
      }
    }
  }

  Future<void> _syncBackgroundPlayback() => _setBackgroundPlayback(
    _player.playing || _activeAmbienceSounds.isNotEmpty,
  );

  Future<void> _selectAmbience(NovelAmbientSound sound) async {
    if (sound == NovelAmbientSound.none) {
      _updateState(() => _activeAmbienceSounds.clear());
      await _stopAllAmbience();
      await _syncBackgroundPlayback();
      return;
    }
    final enabled = _activeAmbienceSounds.contains(sound);
    if (!enabled && !await _ambience.isCached(sound)) {
      final downloaded = await _downloadAmbience(sound, showSuccess: false);
      if (!downloaded || !mounted) return;
    }
    _updateState(() {
      if (enabled) {
        _activeAmbienceSounds.remove(sound);
      } else {
        _activeAmbienceSounds.add(sound);
      }
    });
    if (enabled) {
      await _stopAmbienceSound(sound);
    } else {
      await _playAmbienceSound(sound);
    }
    await _syncBackgroundPlayback();
  }

  Future<bool> _downloadAmbience(
    NovelAmbientSound sound, {
    bool showSuccess = true,
  }) async {
    if (_downloadingAmbienceSounds.contains(sound)) return false;
    _updateState(() => _downloadingAmbienceSounds.add(sound));
    try {
      await _ambience.downloadFromStorage(sound);
      if (!mounted) return false;
      if (showSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحميل ${sound.label} للاستخدام دون اتصال'),
          ),
        );
      }
      if (_activeAmbienceSounds.contains(sound)) {
        await _playAmbienceSound(sound);
      }
      return true;
    } catch (error, stackTrace) {
      AppLogger.log(
        'Ambient UI download failed: sound=${sound.name}, label=${sound.label}',
        name: 'NOVEL_AMBIENCE_UI',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل ${sound.label}: $error')),
        );
      }
      return false;
    } finally {
      if (mounted) {
        _updateState(() => _downloadingAmbienceSounds.remove(sound));
      } else {
        _downloadingAmbienceSounds.remove(sound);
      }
    }
  }

  Future<void> _playAmbienceSound(NovelAmbientSound sound) async {
    try {
      final path = await _ambience.createFile(sound);
      final player = _ambiencePlayers.putIfAbsent(
        sound,
        AmbientCrossfadePlayer.new,
      );
      await player.play(
        path,
        volume: (_ambienceVolumes[sound] ?? .25)
            .clamp(0, _maxAmbienceVolume)
            .toDouble(),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تشغيل ${sound.label}: $error')),
        );
      }
    }
  }

  Future<void> _stopAmbienceSound(NovelAmbientSound sound) async {
    await _ambiencePlayers[sound]?.stop();
  }

  Future<void> _stopAllAmbience() async {
    for (final player in _ambiencePlayers.values) {
      await player.stop();
    }
  }

  Future<void> _setAmbienceVolume(NovelAmbientSound sound, double value) async {
    final safeValue = value.clamp(0, _maxAmbienceVolume).toDouble();
    _updateState(() => _ambienceVolumes[sound] = safeValue);
    await _ambiencePlayers[sound]?.setVolume(safeValue);
  }
}
