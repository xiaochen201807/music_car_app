import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'native_audio_controller.dart';

Future<MusicAudioHandler> initMusicAudioHandler() async {
  final AudioSession session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  return AudioService.init<MusicAudioHandler>(
    builder: MusicAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.sy110.music_car_app.audio',
      androidNotificationChannelName: '车载音乐播放',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
      androidBrowsableRootExtras: <String, Object>{
        AndroidContentStyle.supportedKey: true,
        AndroidContentStyle.playableHintKey:
            AndroidContentStyle.listItemHintValue,
        AndroidContentStyle.browsableHintKey:
            AndroidContentStyle.listItemHintValue,
      },
    ),
  );
}

class MusicAudioHandler extends BaseAudioHandler implements NativeAudioPlayer {
  MusicAudioHandler({NativeAudioPlayer? player})
    : _player = player ?? JustAudioNativePlayer() {
    _playbackSubscription = _player.playbackEventStream.listen(
      _broadcastPlaybackState,
    );
    _stallTimer = Timer.periodic(_stallCheckInterval, (_) {
      unawaited(checkForPlaybackStall());
    });
  }

  static const Duration _stallCheckInterval = Duration(seconds: 2);
  static const Duration _stallSkipThreshold = Duration(seconds: 10);

  final NativeAudioPlayer _player;
  late final StreamSubscription<PlaybackEvent> _playbackSubscription;
  late final Timer _stallTimer;
  Future<bool> Function()? onPlayTrack;
  Future<void> Function()? onSkipToNextTrack;
  Future<void> Function()? onSkipToPreviousTrack;
  bool _handlingPlayCallback = false;
  bool _autoSkippingToNext = false;
  Duration? _lastObservedPosition;
  DateTime? _lastPlaybackProgressAt;

  @override
  Stream<PlaybackEvent> get playbackEventStream => _player.playbackEventStream;

  @override
  ProcessingState get processingState => _player.processingState;

  @override
  bool get playing => _player.playing;

  @override
  Duration get position => _player.position;

  @override
  Duration get bufferedPosition => _player.bufferedPosition;

  @override
  double get speed => _player.speed;

  @override
  Future<Duration?> setUrl(String url) => _player.setUrl(url);

  @override
  Future<void> loadFromSnapshot(
    String url,
    PlayerProbeSnapshot snapshot,
  ) async {
    _autoSkippingToNext = false;
    _resetPlaybackStallMonitor();
    final MediaItem item = MediaItem(
      id: url,
      title: snapshot.title.isEmpty ? '未知歌曲' : snapshot.title,
      artist: snapshot.artist.isEmpty ? null : snapshot.artist,
      artUri: snapshot.coverUrl.isEmpty
          ? null
          : Uri.tryParse(snapshot.coverUrl),
      duration: snapshot.duration > Duration.zero ? snapshot.duration : null,
      playable: true,
      extras: <String, Object?>{
        'source': snapshot.song?.source,
        'songId': snapshot.song?.id,
        'audioUrl': url,
        AndroidContentStyle.playableHintKey:
            AndroidContentStyle.listItemHintValue,
      },
    );
    mediaItem.add(item);
    queueTitle.add('当前播放');
    queue.add(<MediaItem>[item]);
    await setUrl(url);
  }

  @override
  Future<void> play() async {
    if (!_handlingPlayCallback && onPlayTrack != null) {
      _handlingPlayCallback = true;
      try {
        final bool handled = await onPlayTrack!.call();
        if (handled) {
          return;
        }
      } finally {
        _handlingPlayCallback = false;
      }
    }
    await _player.play();
  }

  @override
  Future<void> pause() async {
    _resetPlaybackStallMonitor();
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    _resetPlaybackStallMonitor();
    await _player.seek(position);
  }

  @override
  Future<void> stop() async {
    _resetPlaybackStallMonitor();
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
  Future<void> skipToQueueItem(int index) async {
    if (index == 0 && mediaItem.valueOrNull != null) {
      await play();
    }
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    if (this.mediaItem.valueOrNull?.id == mediaItem.id) {
      await play();
    }
  }

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    return queue.valueOrNull ?? const <MediaItem>[];
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    final MediaItem? current = mediaItem.valueOrNull;
    return current?.id == mediaId ? current : null;
  }

  @override
  Future<void> dispose() async {
    _stallTimer.cancel();
    await _playbackSubscription.cancel();
    await _player.dispose();
    await super.stop();
  }

  void _broadcastPlaybackState(PlaybackEvent event) {
    if (event.processingState == ProcessingState.completed) {
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
        processingState: _mapProcessingState(event.processingState),
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: mediaItem.valueOrNull == null ? null : 0,
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

  @visibleForTesting
  Future<void> checkForPlaybackStall([DateTime? now]) async {
    if (!_player.playing || mediaItem.valueOrNull == null) {
      _resetPlaybackStallMonitor(now: now);
      return;
    }

    final DateTime observedAt = now ?? DateTime.now();
    final Duration currentPosition = _player.position;
    final Duration? lastPosition = _lastObservedPosition;

    if (lastPosition == null || currentPosition > lastPosition) {
      _lastObservedPosition = currentPosition;
      _lastPlaybackProgressAt = observedAt;
      return;
    }

    _lastObservedPosition = currentPosition;
    final DateTime stalledSince = _lastPlaybackProgressAt ?? observedAt;
    _lastPlaybackProgressAt ??= observedAt;

    if (observedAt.difference(stalledSince) < _stallSkipThreshold) {
      return;
    }
    if (_autoSkippingToNext) {
      return;
    }

    debugPrint(
      '[native-audio] playback stalled for '
      '${observedAt.difference(stalledSince).inSeconds}s, skipping next',
    );
    await autoSkipToNextAfterCompletion();
  }

  void _resetPlaybackStallMonitor({DateTime? now}) {
    _lastObservedPosition = null;
    _lastPlaybackProgressAt = now;
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
