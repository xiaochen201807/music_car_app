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
    this.playlist = const <FreeMusicSong>[],
    this.currentIndex = -1,
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
      playlist: _playlistValue(payload['playlist']),
      currentIndex: _intValue(payload['currentIndex'], defaultValue: -1),
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
  final List<FreeMusicSong> playlist;
  final int currentIndex;
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
  List<FreeMusicSong> _playlist = const <FreeMusicSong>[];
  int _currentIndex = -1;

  @visibleForTesting
  List<FreeMusicSong> get playlist => _playlist;

  @visibleForTesting
  int get currentIndex => _currentIndex;

  Future<bool> syncFromProbe(PlayerProbeSnapshot snapshot) async {
    _syncQueue(snapshot);
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

  Future<bool> skipToNext() async {
    return _skipToQueueOffset(1);
  }

  Future<bool> skipToPrevious() async {
    return _skipToQueueOffset(-1);
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

  void _syncQueue(PlayerProbeSnapshot snapshot) {
    if (snapshot.playlist.isEmpty) {
      return;
    }
    _playlist = List<FreeMusicSong>.unmodifiable(snapshot.playlist);
    if (snapshot.currentIndex >= 0 &&
        snapshot.currentIndex < _playlist.length) {
      _currentIndex = snapshot.currentIndex;
      return;
    }
    _currentIndex = _indexOfSong(snapshot.song);
  }

  Future<bool> _skipToQueueOffset(int offset) async {
    if (_playlist.isEmpty || _currentIndex < 0) {
      return false;
    }
    final int targetIndex = _currentIndex + offset;
    if (targetIndex < 0 || targetIndex >= _playlist.length) {
      return false;
    }
    return _loadQueueIndex(targetIndex);
  }

  Future<bool> _loadQueueIndex(int index) async {
    final FreeMusicSong song = _playlist[index];
    if (!song.canResolve) {
      return false;
    }
    final PlayerProbeSnapshot snapshot = PlayerProbeSnapshot(
      audioUrl: '',
      playing: true,
      song: song,
      playlist: _playlist,
      currentIndex: index,
      title: song.name,
      artist: song.artist,
      duration: Duration(seconds: song.duration),
    );
    final String audioUrl = await _resolveAudioUrl(snapshot);
    if (audioUrl.isEmpty) {
      return false;
    }
    _currentIndex = index;
    _loadedUrl = audioUrl;
    await _player.loadFromSnapshot(audioUrl, snapshot);
    await _player.play();
    debugPrint('[native-audio] skipped to ${snapshot.debugTitle}');
    return true;
  }

  int _indexOfSong(FreeMusicSong? song) {
    if (song == null) {
      return -1;
    }
    for (int index = 0; index < _playlist.length; index += 1) {
      final FreeMusicSong candidate = _playlist[index];
      if (candidate.id == song.id && candidate.source == song.source) {
        return index;
      }
    }
    return -1;
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

List<FreeMusicSong> _playlistValue(Object? value) {
  if (value is! Iterable) {
    return const <FreeMusicSong>[];
  }
  return value
      .whereType<Map>()
      .map(
        (Map<Object?, Object?> item) => FreeMusicSong(
          id: _stringValue(item['id']),
          source: _stringValue(item['source']),
          name: _stringValue(item['name'] ?? item['title']),
          artist: _stringValue(item['artist']),
          duration: _intValue(item['duration']),
        ),
      )
      .where((FreeMusicSong song) => song.canResolve)
      .toList(growable: false);
}
