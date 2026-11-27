part of '../novel_reader_state.dart';

extension _ReaderPlayerSettings on NovelReaderState {
  Future<void> _seekBy(Duration delta) async {
    final target = _position + delta;
    await _player.seek(
      Duration(
        milliseconds: target.inMilliseconds
            .clamp(0, _duration.inMilliseconds)
            .toInt(),
      ),
    );
  }

  Future<void> _setPlaybackRate(double value) async {
    _updateState(() => _playbackRate = value);
    await _player.setSpeed(value);
    _schedulePreferencesSave();
  }

  Future<void> _setWordPlaybackRate(double value) async {
    _updateState(() => _wordPlaybackRate = value);
    if (_wordPlayer.playing) {
      await _wordPlayer.setSpeed(value);
    }
    _schedulePreferencesSave();
  }

  String _formatPlaybackRate(double rate) =>
      rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : '$rate';

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get _playbackRateLabel {
    final value = _playbackRate == _playbackRate.roundToDouble()
        ? _playbackRate.toStringAsFixed(0)
        : _playbackRate.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    return '${value}x';
  }
}
