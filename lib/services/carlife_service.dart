import 'package:flutter/services.dart';

import '../free_music_api.dart';

class CarLifeService {
  const CarLifeService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('music_car_app/carlife');

  final MethodChannel _channel;

  Future<CarLifeStatus> getStatus() async {
    try {
      final Object? result = await _channel.invokeMethod<Object?>('getStatus');
      return CarLifeStatus.fromMap(_asStringKeyMap(result));
    } on MissingPluginException {
      return const CarLifeStatus(
        available: false,
        installed: false,
        launchable: false,
        sdkLinked: false,
        reason: 'not_android',
      );
    } on PlatformException catch (error) {
      return CarLifeStatus(
        available: false,
        installed: false,
        launchable: false,
        sdkLinked: false,
        reason: error.code,
      );
    }
  }

  Future<CarLifeLaunchResult> openCarLife() async {
    try {
      final Object? result = await _channel.invokeMethod<Object?>(
        'openCarLife',
      );
      return CarLifeLaunchResult.fromMap(_asStringKeyMap(result));
    } on MissingPluginException {
      return const CarLifeLaunchResult(launched: false, reason: 'not_android');
    } on PlatformException catch (error) {
      return CarLifeLaunchResult(launched: false, reason: error.code);
    }
  }

  Future<CarLifeSyncResult> syncPlaybackContext({
    required String title,
    required String artist,
    required bool playing,
    CarLifePlaybackContext? context,
  }) async {
    try {
      final Object? result = await _channel.invokeMethod<Object?>(
        'syncPlaybackContext',
        context?.toMap() ??
            <String, Object?>{
              'title': title,
              'artist': artist,
              'playing': playing,
            },
      );
      return CarLifeSyncResult.fromMap(_asStringKeyMap(result));
    } on MissingPluginException {
      return const CarLifeSyncResult(supported: false, reason: 'not_android');
    } on PlatformException catch (error) {
      return CarLifeSyncResult(supported: false, reason: error.code);
    }
  }
}

class CarLifePlaybackContext {
  const CarLifePlaybackContext({
    required this.title,
    required this.artist,
    required this.playing,
    this.album = '',
    this.coverUrl = '',
    this.source = '',
    this.songId = '',
    this.duration = Duration.zero,
    this.position = Duration.zero,
    this.queue = const <FreeMusicSong>[],
    this.queueIndex = -1,
  });

  final String title;
  final String artist;
  final bool playing;
  final String album;
  final String coverUrl;
  final String source;
  final String songId;
  final Duration duration;
  final Duration position;
  final List<FreeMusicSong> queue;
  final int queueIndex;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'title': title,
      'artist': artist,
      'album': album,
      'coverUrl': coverUrl,
      'source': source,
      'songId': songId,
      'playing': playing,
      'durationMs': duration.inMilliseconds,
      'positionMs': position.inMilliseconds,
      'queueIndex': queueIndex,
      'queue': queue.map(_songToMap).toList(growable: false),
    };
  }
}

Map<String, Object?> _songToMap(FreeMusicSong song) {
  return <String, Object?>{
    'id': song.id,
    'source': song.source,
    'name': song.name,
    'artist': song.artist,
    'album': song.album,
    'duration': song.duration,
    'cover': song.cover,
  };
}

class CarLifeStatus {
  const CarLifeStatus({
    required this.available,
    required this.installed,
    required this.launchable,
    required this.sdkLinked,
    this.packageName = '',
    this.integrationMode = '',
    this.reason = '',
  });

  factory CarLifeStatus.fromMap(Map<String, Object?> map) {
    return CarLifeStatus(
      available: map['available'] == true,
      installed: map['installed'] == true,
      launchable: map['launchable'] == true,
      sdkLinked: map['sdkLinked'] == true,
      packageName: _stringValue(map['packageName']),
      integrationMode: _stringValue(map['integrationMode']),
      reason: _stringValue(map['reason']),
    );
  }

  final bool available;
  final bool installed;
  final bool launchable;
  final bool sdkLinked;
  final String packageName;
  final String integrationMode;
  final String reason;

  String get displayText {
    if (sdkLinked) {
      return 'SDK 已接入';
    }
    if (launchable) {
      return '已安装，可拉起';
    }
    if (installed) {
      return '已安装，未找到启动入口';
    }
    return '未检测到 CarLife';
  }
}

class CarLifeLaunchResult {
  const CarLifeLaunchResult({
    required this.launched,
    this.packageName = '',
    this.reason = '',
  });

  factory CarLifeLaunchResult.fromMap(Map<String, Object?> map) {
    return CarLifeLaunchResult(
      launched: map['launched'] == true,
      packageName: _stringValue(map['packageName']),
      reason: _stringValue(map['reason']),
    );
  }

  final bool launched;
  final String packageName;
  final String reason;
}

class CarLifeSyncResult {
  const CarLifeSyncResult({
    required this.supported,
    this.reason = '',
    this.packageName = '',
    this.integrationMode = '',
    this.syncedQueueLength = 0,
    this.syncedQueueIndex = -1,
    this.syncedTitle = '',
  });

  factory CarLifeSyncResult.fromMap(Map<String, Object?> map) {
    return CarLifeSyncResult(
      supported: map['supported'] == true,
      reason: _stringValue(map['reason']),
      packageName: _stringValue(map['packageName']),
      integrationMode: _stringValue(map['integrationMode']),
      syncedQueueLength: _intValue(map['syncedQueueLength']),
      syncedQueueIndex: _intValue(map['syncedQueueIndex'], defaultValue: -1),
      syncedTitle: _stringValue(map['syncedTitle']),
    );
  }

  final bool supported;
  final String reason;
  final String packageName;
  final String integrationMode;
  final int syncedQueueLength;
  final int syncedQueueIndex;
  final String syncedTitle;
}

Map<String, Object?> _asStringKeyMap(Object? value) {
  if (value is Map) {
    return value.map(
      (Object? key, Object? value) => MapEntry<String, Object?>('$key', value),
    );
  }
  return const <String, Object?>{};
}

String _stringValue(Object? value) {
  if (value == null) {
    return '';
  }
  return '$value'.trim();
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
