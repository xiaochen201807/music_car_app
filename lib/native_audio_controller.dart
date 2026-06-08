import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'free_music_api.dart';

const String pauseWebAudioScript = r'''
(function() {
  window.__musicCarNativeAudioActive = true;
  window.__musicCarSuppressPauseUntil = Date.now() + 1500;
  document.querySelectorAll('audio').forEach(function(audio) {
    audio.pause();
    audio.muted = true;
  });
})();
''';

const String clickNextTrackScript = r'''
(function() {
  var button = document.querySelector('.music-btn-next');
  if (!button) {
    return false;
  }
  button.click();
  return true;
})();
''';

const String clickPreviousTrackScript = r'''
(function() {
  var button = document.querySelector('.music-btn-prev');
  if (!button) {
    return false;
  }
  button.click();
  return true;
})();
''';

class PlayerProbeSnapshot {
  const PlayerProbeSnapshot({
    required this.audioUrl,
    required this.playing,
    this.song,
    this.title = '',
    this.artist = '',
    this.coverUrl = '',
    this.currentTime = Duration.zero,
    this.duration = Duration.zero,
  });

  factory PlayerProbeSnapshot.fromPayload(Map<Object?, Object?> payload) {
    return PlayerProbeSnapshot(
      audioUrl: _stringValue(payload['audioUrl']),
      playing: payload['playing'] == true,
      song: FreeMusicSong(
        id: _stringValue(payload['id']),
        source: _stringValue(payload['source']),
        name: _stringValue(payload['title']),
        artist: _stringValue(payload['artist']),
        duration: _intValue(payload['duration']),
      ),
      title: _stringValue(payload['title']),
      artist: _stringValue(payload['artist']),
      coverUrl: _stringValue(payload['coverUrl']),
      currentTime: _durationFromSeconds(payload['currentTime']),
      duration: _durationFromSeconds(payload['duration']),
    );
  }

  final String audioUrl;
  final bool playing;
  final FreeMusicSong? song;
  final String title;
  final String artist;
  final String coverUrl;
  final Duration currentTime;
  final Duration duration;

  bool get hasAudioUrl =>
      audioUrl.startsWith('http://') || audioUrl.startsWith('https://');

  bool get canResolveAudioUrl => song?.canResolve ?? false;

  String get debugTitle {
    if (title.isEmpty && artist.isEmpty) {
      return '未知歌曲';
    }
    if (artist.isEmpty) {
      return title;
    }
    if (title.isEmpty) {
      return artist;
    }
    return '$title - $artist';
  }
}

abstract class NativeAudioPlayer {
  Stream<PlaybackEvent> get playbackEventStream;

  ProcessingState get processingState;

  bool get playing;

  Duration get position;

  Duration get bufferedPosition;

  double get speed;

  Future<Duration?> setUrl(String url);

  Future<void> loadFromSnapshot(String url, PlayerProbeSnapshot snapshot);

  Future<void> seek(Duration position);

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  Future<void> dispose();
}

class JustAudioNativePlayer implements NativeAudioPlayer {
  JustAudioNativePlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

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
    await setUrl(url);
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

class NativeAudioController {
  NativeAudioController({NativeAudioPlayer? player, FreeMusicApi? api})
    : _player = player ?? JustAudioNativePlayer(),
      _api = api ?? FreeMusicApi();

  final NativeAudioPlayer _player;
  final FreeMusicApi _api;
  String _loadedUrl = '';

  Future<bool> syncFromProbe(PlayerProbeSnapshot snapshot) async {
    final String audioUrl = await _resolveAudioUrl(snapshot);
    if (audioUrl.isEmpty) {
      return false;
    }
    if (_loadedUrl != audioUrl) {
      _loadedUrl = audioUrl;
      await _player.loadFromSnapshot(audioUrl, snapshot);
      if (snapshot.currentTime > Duration.zero) {
        await _player.seek(snapshot.currentTime);
      }
      debugPrint('[native-audio] loaded ${snapshot.debugTitle}');
    }
    if (snapshot.playing) {
      await _player.play();
      debugPrint('[native-audio] playing ${snapshot.debugTitle}');
    } else {
      await _player.pause();
      debugPrint('[native-audio] paused ${snapshot.debugTitle}');
    }
    return true;
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> dispose() async {
    _api.close();
    await _player.dispose();
  }

  Future<String> _resolveAudioUrl(PlayerProbeSnapshot snapshot) async {
    if (snapshot.hasAudioUrl) {
      return snapshot.audioUrl;
    }
    final FreeMusicSong? song = snapshot.song;
    if (song == null || !song.canResolve) {
      return '';
    }
    final FreeMusicResolvedUrl? resolved = await _api.resolveSongUrl(song);
    final String url = resolved?.url ?? '';
    if (url.isNotEmpty) {
      debugPrint('[native-audio] resolved ${snapshot.debugTitle}');
    }
    return url;
  }
}

String _stringValue(Object? value) {
  if (value == null) {
    return '';
  }
  return '$value'.trim();
}

Duration _durationFromSeconds(Object? value) {
  if (value is num && value.isFinite && value > 0) {
    return Duration(milliseconds: (value * 1000).round());
  }
  if (value is String) {
    final double? parsed = double.tryParse(value);
    if (parsed != null && parsed.isFinite && parsed > 0) {
      return Duration(milliseconds: (parsed * 1000).round());
    }
  }
  return Duration.zero;
}

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num && value.isFinite) {
    return value.round();
  }
  if (value is String) {
    return double.tryParse(value)?.round() ?? 0;
  }
  return 0;
}
