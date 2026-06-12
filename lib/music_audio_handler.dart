import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import 'free_music_api.dart';
import 'native_audio_controller.dart';
import 'utils/lyrics_utils.dart';

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
    _lyricTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkAndUpdateCarLifeLyric();
    });
  }

  static const Duration _stallCheckInterval = Duration(seconds: 2);
  static const Duration _stallSkipThreshold = Duration(seconds: 10);
  static const Duration _seekStep = Duration(seconds: 15);
  static const Duration _continuousSeekInterval = Duration(milliseconds: 500);
  static const Duration _playbackStateHeartbeat = Duration(seconds: 1);
  static const Duration _playbackPositionDriftThreshold = Duration(
    milliseconds: 500,
  );
  static const Duration _bufferedPositionChangeThreshold = Duration(seconds: 1);

  static const MethodChannel _carLifeChannel = MethodChannel(
    'music_car_app/carlife',
  );
  List<FreeMusicLyricLine> _currentLyricLines = const [];
  String _lastBroadcastLyric = '';
  late final Timer _lyricTimer;

  final NativeAudioPlayer _player;
  late final StreamSubscription<PlaybackEvent> _playbackSubscription;
  late final Timer _stallTimer;
  Timer? _continuousSeekTimer;
  Future<bool> Function()? onPlayTrack;
  Future<void> Function()? onPauseTrack;
  Future<bool> Function()? onSkipToNextTrack;
  Future<bool> Function()? onSkipToPreviousTrack;
  Future<void> Function(int index)? onSkipToQueueItem;
  Future<void> Function(AudioServiceRepeatMode repeatMode)? onSetRepeatMode;
  Future<void> Function(AudioServiceShuffleMode shuffleMode)? onSetShuffleMode;
  bool _handlingPlayCallback = false;
  bool _handlingPauseCallback = false;
  bool _autoSkippingToNext = false; // 操作级防重入：await 完成后释放
  bool _isBroadcastingPlaybackState = false;
  bool _pendingPlaybackStateBroadcast = false;
  int? _activeQueueIndex;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  AudioServiceShuffleMode _shuffleMode = AudioServiceShuffleMode.none;
  Duration? _lastObservedPosition;
  DateTime? _lastPlaybackProgressAt;

  @override
  Stream<PlaybackEvent> get playbackEventStream => _player.playbackEventStream;

  @override
  PlaybackEvent get playbackEvent => _player.playbackEvent;

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
    final List<MediaItem> publishedQueue = _mediaQueueFromSnapshot(
      snapshot,
      fallbackItem: item,
    );
    _activeQueueIndex = _queueIndexFromSnapshot(
      snapshot,
      publishedQueue: publishedQueue,
      fallbackItem: item,
    );
    queue.add(publishedQueue);
    _broadcastPlaybackState(_player.playbackEvent);
    await setUrl(url);
  }

  @override
  Future<void> play() async {
    debugPrint('[audio-handler] play() called');
    if (!_handlingPlayCallback && onPlayTrack != null) {
      _handlingPlayCallback = true;
      try {
        await onPlayTrack!.call();
      } catch (error) {
        debugPrint('[audio-handler] onPlayTrack failed: $error');
      } finally {
        _handlingPlayCallback = false;
      }
    }
    // 不再调用 playDirect()，由 resumePlayback() 内部处理
    debugPrint('[audio-handler] play() completed');
  }

  @override
  Future<void> playDirect() async {
    await _player.play();
    _broadcastPlaybackState(_player.playbackEvent);
  }

  @override
  Future<void> pause() async {
    _resetPlaybackStallMonitor();
    if (!_handlingPauseCallback && onPauseTrack != null) {
      _handlingPauseCallback = true;
      try {
        await onPauseTrack!.call();
      } catch (error) {
        debugPrint('[audio-handler] onPauseTrack failed: $error');
      } finally {
        _handlingPauseCallback = false;
      }
    }
    await pauseDirect();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _broadcastPlaybackState(_player.playbackEvent);
  }

  @override
  Future<void> pauseDirect() async {
    _resetPlaybackStallMonitor();
    await _player.pause();
    _broadcastPlaybackState(_player.playbackEvent);
  }

  @override
  Future<void> seek(Duration position) async {
    _resetPlaybackStallMonitor();
    await _player.seek(_boundedSeekPosition(position));
  }

  @override
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  @override
  Future<void> fastForward() => _seekRelative(_seekStep);

  @override
  Future<void> rewind() => _seekRelative(-_seekStep);

  @override
  Future<void> seekForward(bool begin) async {
    await _setContinuousSeek(begin: begin, step: _seekStep);
  }

  @override
  Future<void> seekBackward(bool begin) async {
    await _setContinuousSeek(begin: begin, step: -_seekStep);
  }

  @override
  Future<void> stop() async {
    _resetPlaybackStallMonitor();
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    try {
      await onSkipToNextTrack?.call();
    } catch (error) {
      debugPrint('[audio-handler] onSkipToNextTrack failed: $error');
    } finally {
      _broadcastPlaybackState(_player.playbackEvent);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      await onSkipToPreviousTrack?.call();
    } catch (error) {
      debugPrint('[audio-handler] onSkipToPreviousTrack failed: $error');
    } finally {
      _broadcastPlaybackState(_player.playbackEvent);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    final List<MediaItem> items = queue.valueOrNull ?? const <MediaItem>[];
    if (index < 0 || index >= items.length) {
      return;
    }
    if (index == _activeQueueIndex && mediaItem.valueOrNull != null) {
      await play();
      return;
    }
    await onSkipToQueueItem?.call(index);
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    final List<MediaItem> items = queue.valueOrNull ?? const <MediaItem>[];
    final int index = _queueIndexForMediaItem(items, mediaItem);
    if (index >= 0) {
      await skipToQueueItem(index);
    }
  }

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    final List<MediaItem> items = queue.valueOrNull ?? const <MediaItem>[];
    final int index = _queueIndexForMediaId(items, mediaId, extras: extras);
    if (index >= 0) {
      await skipToQueueItem(index);
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;
    _broadcastPlaybackState(_player.playbackEvent);
    await onSetRepeatMode?.call(repeatMode);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _shuffleMode = shuffleMode;
    _broadcastPlaybackState(_player.playbackEvent);
    await onSetShuffleMode?.call(shuffleMode);
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
    if (current?.id == mediaId) {
      return current;
    }
    for (final MediaItem item in queue.valueOrNull ?? const <MediaItem>[]) {
      if (_mediaItemMatchesId(item, mediaId)) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<void> dispose() async {
    _continuousSeekTimer?.cancel();
    _stallTimer.cancel();
    _lyricTimer.cancel();
    await _playbackSubscription.cancel();
    await _player.dispose();
    await super.stop();
  }

  void updateLyrics(List<FreeMusicLyricLine> lines) {
    _currentLyricLines = lines;
    _lastBroadcastLyric = '';
  }

  void _checkAndUpdateCarLifeLyric() {
    if (_currentLyricLines.isEmpty) {
      if (_lastBroadcastLyric != '暂无歌词') {
        _lastBroadcastLyric = '暂无歌词';
        _sendLyricBroadcast('暂无歌词');
      }
      return;
    }
    if (!_player.playing) {
      return;
    }
    final Duration currentPos = _player.position;
    final int index = activeLyricLineIndex(
      _currentLyricLines,
      currentPos,
      lead: lyricHighlightLead,
    );
    if (index >= 0 && index < _currentLyricLines.length) {
      final String lyric = _currentLyricLines[index].text;
      if (lyric != _lastBroadcastLyric) {
        _lastBroadcastLyric = lyric;
        _sendLyricBroadcast(lyric);
      }
    }
  }

  void _sendLyricBroadcast(String lyric) {
    final MediaItem? currentItem = mediaItem.valueOrNull;
    final String title = currentItem?.title ?? '';
    final String artist = currentItem?.artist ?? '';
    final String album = currentItem?.album ?? '';
    final int durationMs = currentItem?.duration?.inMilliseconds ?? 0;
    final int positionMs = _player.position.inMilliseconds;
    final bool playing = _player.playing;

    unawaited(
      _carLifeChannel
          .invokeMethod<void>('sendLyricBroadcast', <String, Object?>{
            'lyric': lyric,
            'title': title,
            'artist': artist,
            'album': album,
            'duration': durationMs,
            'position': positionMs,
            'playing': playing,
          }),
    );
  }

  void _broadcastPlaybackState(PlaybackEvent event) {
    if (event.processingState == ProcessingState.completed) {
      unawaited(autoSkipToNextAfterCompletion());
    }

    if (_isBroadcastingPlaybackState) {
      _pendingPlaybackStateBroadcast = true;
      return;
    }
    _isBroadcastingPlaybackState = true;

    final bool playing = _player.playing;
    final PlaybackState nextState = PlaybackState(
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
        MediaAction.play,
        MediaAction.pause,
        MediaAction.playPause,
        MediaAction.stop,
      },
      androidCompactActionIndices: const <int>[0, 1, 2],
      processingState: _mapProcessingState(event.processingState),
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _activeQueueIndex,
      repeatMode: _repeatMode,
      shuffleMode: _shuffleMode,
      updateTime: DateTime.now(),
    );

    try {
      if (_shouldBroadcastPlaybackState(playbackState.valueOrNull, nextState)) {
        playbackState.add(nextState);
      }
    } finally {
      _isBroadcastingPlaybackState = false;
      if (_pendingPlaybackStateBroadcast) {
        _pendingPlaybackStateBroadcast = false;
        _broadcastPlaybackState(_player.playbackEvent);
      }
    }
  }

  @visibleForTesting
  Future<void> autoSkipToNextAfterCompletion() async {
    if (_autoSkippingToNext) {
      return;
    }
    _autoSkippingToNext = true;
    try {
      final bool handled = await onSkipToNextTrack?.call() ?? false;
      if (!handled) {
        await stop();
      }
    } finally {
      _autoSkippingToNext = false;
    }
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
    _resetPlaybackStallMonitor(now: observedAt);
    await autoSkipToNextAfterCompletion();
  }

  Future<void> _seekRelative(Duration offset) async {
    await seek(_player.position + offset);
  }

  Future<void> _setContinuousSeek({
    required bool begin,
    required Duration step,
  }) async {
    _continuousSeekTimer?.cancel();
    _continuousSeekTimer = null;
    if (!begin) {
      return;
    }
    await _seekRelative(step);
    _continuousSeekTimer = Timer.periodic(_continuousSeekInterval, (_) {
      unawaited(_seekRelative(step));
    });
  }

  Duration _boundedSeekPosition(Duration requested) {
    final Duration lowerBounded = requested < Duration.zero
        ? Duration.zero
        : requested;
    final Duration? duration = mediaItem.valueOrNull?.duration;
    if (duration == null || duration <= Duration.zero) {
      return lowerBounded;
    }
    return lowerBounded > duration ? duration : lowerBounded;
  }

  void _resetPlaybackStallMonitor({DateTime? now}) {
    _lastObservedPosition = null;
    _lastPlaybackProgressAt = now;
  }
}

int _queueIndexForMediaItem(List<MediaItem> items, MediaItem mediaItem) {
  return items.indexWhere((MediaItem item) {
    return item.id == mediaItem.id ||
        _mediaItemMatchesSourceAndSong(
          item,
          source: mediaItem.extras?['source'],
          songId: mediaItem.extras?['songId'],
        );
  });
}

int _queueIndexForMediaId(
  List<MediaItem> items,
  String mediaId, {
  Map<String, dynamic>? extras,
}) {
  return items.indexWhere((MediaItem item) {
    return _mediaItemMatchesId(item, mediaId) ||
        _mediaItemMatchesSourceAndSong(
          item,
          source: extras?['source'],
          songId: extras?['songId'],
        );
  });
}

bool _mediaItemMatchesId(MediaItem item, String mediaId) {
  if (item.id == mediaId) {
    return true;
  }
  final Object? source = item.extras?['source'];
  final Object? songId = item.extras?['songId'];
  if (source == null || songId == null) {
    return false;
  }
  return mediaId == '$source:$songId' || mediaId == '$songId';
}

bool _mediaItemMatchesSourceAndSong(
  MediaItem item, {
  required Object? source,
  required Object? songId,
}) {
  if (source == null || songId == null) {
    return false;
  }
  return item.extras?['source'] == source && item.extras?['songId'] == songId;
}

List<MediaItem> _mediaQueueFromSnapshot(
  PlayerProbeSnapshot snapshot, {
  required MediaItem fallbackItem,
}) {
  if (snapshot.playlist.isEmpty) {
    return <MediaItem>[fallbackItem];
  }
  return snapshot.playlist
      .map((FreeMusicSong song) {
        final bool isCurrent =
            snapshot.song?.id == song.id &&
            snapshot.song?.source == song.source;
        return MediaItem(
          id: isCurrent ? fallbackItem.id : '${song.source}:${song.id}',
          title: song.name.isEmpty ? '未知歌曲' : song.name,
          artist: song.artist.isEmpty ? null : song.artist,
          album: song.album.isEmpty ? null : song.album,
          artUri: song.cover.isEmpty ? null : Uri.tryParse(song.cover),
          duration: song.duration > 0 ? Duration(seconds: song.duration) : null,
          playable: true,
          extras: <String, Object?>{
            'source': song.source,
            'songId': song.id,
            if (isCurrent) 'audioUrl': fallbackItem.id,
            AndroidContentStyle.playableHintKey:
                AndroidContentStyle.listItemHintValue,
          },
        );
      })
      .toList(growable: false);
}

int? _queueIndexFromSnapshot(
  PlayerProbeSnapshot snapshot, {
  required List<MediaItem> publishedQueue,
  required MediaItem fallbackItem,
}) {
  if (publishedQueue.isEmpty) {
    return null;
  }
  if (snapshot.currentIndex >= 0 &&
      snapshot.currentIndex < publishedQueue.length) {
    return snapshot.currentIndex;
  }
  final FreeMusicSong? song = snapshot.song;
  if (song != null) {
    final int index = publishedQueue.indexWhere((MediaItem item) {
      return item.extras?['source'] == song.source &&
          item.extras?['songId'] == song.id;
    });
    if (index >= 0) {
      return index;
    }
  }
  final int fallbackIndex = publishedQueue.indexWhere(
    (MediaItem item) => item.id == fallbackItem.id,
  );
  return fallbackIndex >= 0 ? fallbackIndex : 0;
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

bool _shouldBroadcastPlaybackState(PlaybackState? current, PlaybackState next) {
  if (current == null) {
    return true;
  }
  if (current.playing != next.playing ||
      current.processingState != next.processingState ||
      current.queueIndex != next.queueIndex ||
      current.speed != next.speed ||
      current.repeatMode != next.repeatMode ||
      current.shuffleMode != next.shuffleMode) {
    return true;
  }
  if (_durationDelta(current.bufferedPosition, next.bufferedPosition) >=
      MusicAudioHandler._bufferedPositionChangeThreshold) {
    return true;
  }
  if (next.playing &&
      next.updateTime.difference(current.updateTime) >=
          MusicAudioHandler._playbackStateHeartbeat) {
    return true;
  }
  return _hasSignificantPositionDrift(current, next);
}

bool _hasSignificantPositionDrift(PlaybackState current, PlaybackState next) {
  final Duration expectedPosition =
      current.updatePosition +
      (next.updateTime.difference(current.updateTime)) * current.speed;
  return _durationDelta(next.updatePosition, expectedPosition) >
      MusicAudioHandler._playbackPositionDriftThreshold;
}

Duration _durationDelta(Duration left, Duration right) {
  final Duration delta = left - right;
  return delta.isNegative ? -delta : delta;
}
