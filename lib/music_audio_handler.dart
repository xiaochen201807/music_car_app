import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'native_audio_controller.dart';

Future<MusicAudioHandler> initMusicAudioHandler() async {
  return AudioService.init<MusicAudioHandler>(
    builder: MusicAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.sy110.music_car_app.audio',
      androidNotificationChannelName: '车载音乐播放',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}

class MusicAudioHandler extends BaseAudioHandler implements NativeAudioPlayer {
  MusicAudioHandler({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _playbackSubscription = _player.playbackEventStream.listen(
      _broadcastPlaybackState,
    );
  }

  final AudioPlayer _player;
  late final StreamSubscription<PlaybackEvent> _playbackSubscription;
  Future<void> Function()? onSkipToNextTrack;
  Future<void> Function()? onSkipToPreviousTrack;
  bool _autoSkippingToNext = false;

  @override
  Future<Duration?> setUrl(String url) => _player.setUrl(url);

  @override
  Future<void> loadFromSnapshot(
    String url,
    PlayerProbeSnapshot snapshot,
  ) async {
    _autoSkippingToNext = false;
    mediaItem.add(
      MediaItem(
        id: url,
        title: snapshot.title.isEmpty ? '未知歌曲' : snapshot.title,
        artist: snapshot.artist.isEmpty ? null : snapshot.artist,
        artUri: snapshot.coverUrl.isEmpty
            ? null
            : Uri.tryParse(snapshot.coverUrl),
        duration: snapshot.duration > Duration.zero ? snapshot.duration : null,
        extras: <String, Object?>{
          'source': snapshot.song?.source,
          'songId': snapshot.song?.id,
          'audioUrl': url,
        },
      ),
    );
    await setUrl(url);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    await onSkipToNextTrack?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    await onSkipToPreviousTrack?.call();
  }

  @override
  Future<void> dispose() async {
    await _playbackSubscription.cancel();
    await _player.dispose();
    await super.stop();
  }

  void _broadcastPlaybackState(PlaybackEvent event) {
    if (_player.processingState == ProcessingState.completed) {
      unawaited(autoSkipToNextAfterCompletion());
    }

    final bool playing = _player.playing;
    playbackState.add(
      PlaybackState(
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const <int>[0, 1, 2],
        processingState: _mapProcessingState(_player.processingState),
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );
  }

  @visibleForTesting
  Future<void> autoSkipToNextAfterCompletion() async {
    if (_autoSkippingToNext) {
      return;
    }
    _autoSkippingToNext = true;
    await onSkipToNextTrack?.call();
  }
}

AudioProcessingState _mapProcessingState(ProcessingState state) {
  switch (state) {
    case ProcessingState.idle:
      return AudioProcessingState.idle;
    case ProcessingState.loading:
      return AudioProcessingState.loading;
    case ProcessingState.buffering:
      return AudioProcessingState.buffering;
    case ProcessingState.ready:
      return AudioProcessingState.ready;
    case ProcessingState.completed:
      return AudioProcessingState.completed;
  }
}
