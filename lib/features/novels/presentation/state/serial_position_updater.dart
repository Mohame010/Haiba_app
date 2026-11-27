import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

class SerialPositionUpdater extends PositionUpdater {
  SerialPositionUpdater({required super.getPosition, required this.interval});

  final Duration interval;
  Timer? _timer;
  Future<void>? _updateFuture;
  bool _updateQueued = false;
  bool _running = false;

  @override
  Future<void> update() {
    final updateFuture = _updateFuture;
    if (updateFuture != null) {
      _updateQueued = true;
      return updateFuture;
    }

    final completer = Completer<void>();
    _updateFuture = completer.future;
    unawaited(_drainUpdates(completer));
    return completer.future;
  }

  Future<void> _drainUpdates(Completer<void> completer) async {
    try {
      do {
        _updateQueued = false;
        await super.update();
      } while (_updateQueued);
      completer.complete();
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    } finally {
      _updateFuture = null;
    }
  }

  @override
  void start() {
    _timer?.cancel();
    _running = true;
    unawaited(_poll());
  }

  Future<void> _poll() async {
    try {
      await update();
    } finally {
      if (_running) {
        _timer = Timer(interval, () => unawaited(_poll()));
      }
    }
  }

  @override
  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }
}
