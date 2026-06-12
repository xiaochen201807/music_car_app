import 'package:flutter/foundation.dart';

import '../free_music_api.dart';
import '../music_audio_handler.dart';
import '../native_audio_controller.dart';
import '../services/logger_service.dart';
import '../services/playback_error_tracker.dart';

abstract class PlaybackBackend {
  Future<bool> resumePlayback();

  Future<bool> pausePlayback();

  Future<bool> skipToNext();

  Future<bool> skipToPrevious();

  Future<bool> syncFromProbe(PlayerProbeSnapshot snapshot);

  Future<bool> skipToQueueIndex(int index);

  Future<NativePlaybackMode> cyclePlaybackMode();

  Future<void> setPlaybackMode(NativePlaybackMode mode);

  Duration get position;

  Future<void> seek(Duration position);

  Future<bool> playSong(FreeMusicSong song);
}

class NativeAudioPlaybackBackend implements PlaybackBackend {
  const NativeAudioPlaybackBackend(this._controller);

  final NativeAudioController _controller;

  @override
  Future<bool> resumePlayback() => _controller.resumePlayback();

  @override
  Future<bool> pausePlayback() => _controller.pausePlayback();

  @override
  Future<bool> skipToNext() => _controller.skipToNext();

  @override
  Future<bool> skipToPrevious() => _controller.skipToPrevious();

  @override
  Future<bool> syncFromProbe(PlayerProbeSnapshot snapshot) {
    return _controller.syncFromProbe(snapshot);
  }

  @override
  Future<bool> skipToQueueIndex(int index) {
    return _controller.skipToQueueIndex(index);
  }

  @override
  Future<NativePlaybackMode> cyclePlaybackMode() {
    return _controller.cyclePlaybackMode();
  }

  @override
  Future<void> setPlaybackMode(NativePlaybackMode mode) {
    return _controller.setPlaybackMode(mode);
  }

  @override
  Duration get position => _controller.position;

  @override
  Future<void> seek(Duration position) => _controller.seek(position);

  @override
  Future<bool> playSong(FreeMusicSong song) => _controller.playSong(song);
}

class PlaybackController {
  PlaybackController({
    required NativeAudioController nativeAudioController,
    MusicAudioHandler? audioHandler,
    Duration commandDebounce = const Duration(milliseconds: 500),
  }) : this.withBackend(
         backend: NativeAudioPlaybackBackend(nativeAudioController),
         audioHandler: audioHandler,
         commandDebounce: commandDebounce,
       );

  @visibleForTesting
  PlaybackController.withBackend({
    required PlaybackBackend backend,
    MusicAudioHandler? audioHandler,
    Duration commandDebounce = const Duration(milliseconds: 500),
  }) : _backend = backend,
       _audioHandler = audioHandler,
       _commandDebounce = commandDebounce;

  final PlaybackBackend _backend;
  final MusicAudioHandler? _audioHandler;
  final Duration _commandDebounce;
  DateTime? _lastPauseTime;
  DateTime? _lastSkipPreviousTime;
  bool _queueActionBusy = false;
  double _volume = 1.0;

  bool get queueActionBusy => _queueActionBusy;

  double get volume => _volume;

  Future<bool> resumeNativePlayback() {
    return _backend.resumePlayback();
  }

  Future<bool> pauseNativePlayback({DateTime? now}) async {
    final DateTime timestamp = now ?? DateTime.now();
    if (_lastPauseTime != null &&
        timestamp.difference(_lastPauseTime!) < _commandDebounce) {
      debugPrint('[playback-controller] pause debounced');
      return false;
    }
    _lastPauseTime = timestamp;
    final bool handled = await _backend.pausePlayback();
    debugPrint('[playback-controller] pause handled: $handled');
    return handled;
  }

  Future<bool> skipToNext() {
    return _backend.skipToNext();
  }

  Future<bool> skipToPrevious({DateTime? now}) async {
    final DateTime timestamp = now ?? DateTime.now();
    if (_lastSkipPreviousTime != null &&
        timestamp.difference(_lastSkipPreviousTime!) < _commandDebounce) {
      debugPrint('[playback-controller] previous debounced');
      return false;
    }
    _lastSkipPreviousTime = timestamp;
    final bool handled = await _backend.skipToPrevious();
    debugPrint('[playback-controller] previous handled: $handled');
    return handled;
  }

  Future<bool> playSnapshot(PlayerProbeSnapshot snapshot) {
    return _backend.syncFromProbe(snapshot);
  }

  Future<bool> skipToQueueIndex(int index) {
    return _backend.skipToQueueIndex(index);
  }

  Future<NativePlaybackMode> cyclePlaybackMode() {
    return _backend.cyclePlaybackMode();
  }

  Future<void> setPlaybackMode(NativePlaybackMode mode) {
    return _backend.setPlaybackMode(mode);
  }

  Duration get position => _backend.position;

  Future<void> seekNative(Duration position) {
    return _backend.seek(position);
  }

  Future<bool> playSong(FreeMusicSong song) {
    return _backend.playSong(song);
  }

  Future<void> togglePlayback(bool playing) async {
    final MusicAudioHandler? handler = _audioHandler;
    if (handler == null) {
      return;
    }
    if (playing) {
      await handler.pause();
    } else {
      await handler.play();
    }
  }

  Future<void> seekPlayback(Duration position) async {
    await _audioHandler?.seek(position);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _audioHandler?.setVolume(_volume);
  }

  bool beginQueueAction() {
    if (_queueActionBusy) {
      return false;
    }
    _queueActionBusy = true;
    return true;
  }

  void endQueueAction() {
    _queueActionBusy = false;
  }
}
