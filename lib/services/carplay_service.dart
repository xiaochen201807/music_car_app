import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../free_music_api.dart';
import '../music_audio_handler.dart';
import '../native_audio_controller.dart';

/// Apple CarPlay bridge.
///
/// Native iOS side owns the CPTemplate UI. Flutter pushes the current queue /
/// now-playing snapshot over the `music_car_app/carplay` channel and handles
/// remote play/pause/skip/select callbacks.
class CarPlayService {
  CarPlayService({
    required MusicAudioHandler audioHandler,
    required NativeAudioController nativeAudioController,
    MethodChannel? channel,
  }) : _audioHandler = audioHandler,
       _nativeAudioController = nativeAudioController,
       _channel = channel ?? const MethodChannel('music_car_app/carplay');

  final MusicAudioHandler _audioHandler;
  final NativeAudioController _nativeAudioController;
  final MethodChannel _channel;

  StreamSubscription<MediaItem?>? _mediaItemSub;
  StreamSubscription<PlaybackState>? _playbackSub;
  bool _attached = false;
  CarPlayStatus _status = CarPlayStatus.unsupported;
  void Function(CarPlayStatus status)? onStatusChanged;
  Future<bool> Function()? onPlay;
  Future<bool> Function()? onPause;
  Future<bool> Function()? onSkipNext;
  Future<bool> Function()? onSkipPrevious;
  Future<bool> Function(int index)? onSelectQueueIndex;

  CarPlayStatus get status => _status;

  Future<void> init() async {
    if (_attached) {
      return;
    }
    _attached = true;
    _channel.setMethodCallHandler(_handleNativeCall);
    _mediaItemSub = _audioHandler.mediaItem.listen((_) {
      unawaited(syncNowPlaying());
    });
    _playbackSub = _audioHandler.playbackState.listen((_) {
      unawaited(syncNowPlaying());
    });
    await refreshStatus();
    await syncNowPlaying();
  }

  Future<CarPlayStatus> refreshStatus() async {
    try {
      final Object? result = await _channel.invokeMethod<Object?>('getStatus');
      _status = CarPlayStatus.fromMap(_asStringKeyMap(result));
    } on MissingPluginException {
      _status = CarPlayStatus.unsupported;
    } on PlatformException catch (error) {
      _status = CarPlayStatus(
        available: defaultTargetPlatform == TargetPlatform.iOS,
        connected: false,
        reason: error.code,
      );
    }
    onStatusChanged?.call(_status);
    return _status;
  }

  Future<void> syncNowPlaying({
    List<FreeMusicSong>? queue,
    int? queueIndex,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    final MediaItem? item = _audioHandler.mediaItem.valueOrNull;
    final PlaybackState? playback = _audioHandler.playbackState.valueOrNull;
    final List<FreeMusicSong> playlist =
        queue ?? _nativeAudioController.playlist;
    final int index = queueIndex ?? _nativeAudioController.currentIndex;
    final Map<String, Object?> payload = <String, Object?>{
      'title': item?.title ?? '',
      'artist': item?.artist ?? '',
      'album': item?.album ?? '',
      'coverUrl': item?.artUri?.toString() ?? '',
      'playing': playback?.playing ?? false,
      'durationMs': item?.duration?.inMilliseconds ?? 0,
      'positionMs': playback?.updatePosition.inMilliseconds ?? 0,
      'queueIndex': index,
      'queue': playlist
          .map(
            (FreeMusicSong song) => <String, Object?>{
              'id': song.id,
              'source': song.source,
              'name': song.name,
              'artist': song.artist,
              'album': song.album,
              'cover': song.cover,
              'duration': song.duration,
            },
          )
          .toList(growable: false),
    };
    try {
      await _channel.invokeMethod<void>('syncNowPlaying', payload);
    } on MissingPluginException {
      // iOS-only channel.
    } on PlatformException catch (error) {
      debugPrint('[carplay] syncNowPlaying failed: ${error.code}');
    }
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onConnectionChanged':
        final Map<String, Object?> map = _asStringKeyMap(call.arguments);
        _status = CarPlayStatus.fromMap(map);
        onStatusChanged?.call(_status);
        if (_status.connected) {
          unawaited(syncNowPlaying());
        }
        return null;
      case 'onControl':
        return _handleControl(_asStringKeyMap(call.arguments));
      default:
        throw MissingPluginException('Unknown CarPlay callback: ${call.method}');
    }
  }

  Future<Map<String, Object?>> _handleControl(Map<String, Object?> map) async {
    final String action = '${map['action'] ?? ''}'.trim();
    bool handled = false;
    String reason = 'unknown';
    switch (action) {
      case 'play':
        handled = await onPlay?.call() ?? false;
        reason = handled ? 'played' : 'play_unavailable';
      case 'pause':
        handled = await onPause?.call() ?? false;
        reason = handled ? 'paused' : 'pause_unavailable';
      case 'next':
        handled = await onSkipNext?.call() ?? false;
        reason = handled ? 'next' : 'next_unavailable';
      case 'previous':
        handled = await onSkipPrevious?.call() ?? false;
        reason = handled ? 'previous' : 'previous_unavailable';
      case 'selectQueueItem':
        final int index = _intValue(map['queueIndex'], defaultValue: -1);
        if (index < 0) {
          handled = false;
          reason = 'queue_item_not_found';
        } else {
          handled = await onSelectQueueIndex?.call(index) ?? false;
          reason = handled ? 'queue_item_selected' : 'queue_item_failed';
        }
      default:
        handled = false;
        reason = 'unknown_action';
    }
    return <String, Object?>{'handled': handled, 'reason': reason};
  }

  void dispose() {
    unawaited(_mediaItemSub?.cancel());
    unawaited(_playbackSub?.cancel());
    if (_attached) {
      _channel.setMethodCallHandler(null);
    }
    _attached = false;
    debugPrint('[carplay] Disposed');
  }
}

class CarPlayStatus {
  const CarPlayStatus({
    required this.available,
    required this.connected,
    this.reason = '',
  });

  factory CarPlayStatus.fromMap(Map<String, Object?> map) {
    return CarPlayStatus(
      available: map['available'] == true,
      connected: map['connected'] == true,
      reason: '${map['reason'] ?? ''}'.trim(),
    );
  }

  static const CarPlayStatus unsupported = CarPlayStatus(
    available: false,
    connected: false,
    reason: 'not_ios',
  );

  final bool available;
  final bool connected;
  final String reason;

  String get displayText {
    if (!available) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? '当前构建未启用 CarPlay 能力'
          : '仅 iOS 支持 CarPlay';
    }
    if (connected) {
      return '已连接 CarPlay';
    }
    if (reason == 'scene_ready') {
      return '已就绪，等待车机连接';
    }
    if (reason.isNotEmpty) {
      return reason;
    }
    return '未连接';
  }
}

Map<String, Object?> _asStringKeyMap(Object? value) {
  if (value is Map) {
    return value.map(
      (Object? key, Object? value) => MapEntry<String, Object?>('$key', value),
    );
  }
  return const <String, Object?>{};
}

int _intValue(Object? value, {int defaultValue = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num && value.isFinite) {
    return value.round();
  }
  if (value is String) {
    return double.tryParse(value)?.round() ?? defaultValue;
  }
  return defaultValue;
}
