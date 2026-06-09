import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'free_music_api.dart';

enum NativePlaybackMode {
  sequential,
  repeatOne,
  repeatAll,
  shuffle;

  String get storageValue => name;

  NativePlaybackMode get nextMode {
    switch (this) {
      case NativePlaybackMode.sequential:
        return NativePlaybackMode.repeatAll;
      case NativePlaybackMode.repeatAll:
        return NativePlaybackMode.repeatOne;
      case NativePlaybackMode.repeatOne:
        return NativePlaybackMode.shuffle;
      case NativePlaybackMode.shuffle:
        return NativePlaybackMode.sequential;
    }
  }

  static NativePlaybackMode fromStorageValue(String value) {
    for (final NativePlaybackMode mode in NativePlaybackMode.values) {
      if (mode.storageValue == value) {
        return mode;
      }
    }
    return NativePlaybackMode.sequential;
  }
}

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

  PlaybackEvent get playbackEvent;

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
  NativeAudioController({
    NativeAudioPlayer? player,
    FreeMusicApi? api,
    SharedPreferences? preferences,
  }) : _player = player ?? JustAudioNativePlayer(),
       _api = api ?? FreeMusicApi(),
       _preferences = preferences {
    _restoreFuture = _restoreState();
  }

  static const String _statePreferenceKey = 'native_audio_state_v1';

  final NativeAudioPlayer _player;
  final FreeMusicApi _api;
  final SharedPreferences? _preferences;
  late final Future<void> _restoreFuture;
  String _loadedUrl = '';
  PlayerProbeSnapshot? _loadedSnapshot;
  List<FreeMusicSong> _playlist = const <FreeMusicSong>[];
  int _currentIndex = -1;
  NativePlaybackMode _playbackMode = NativePlaybackMode.sequential;
  final math.Random _random = math.Random();

  @visibleForTesting
  List<FreeMusicSong> get playlist => _playlist;

  @visibleForTesting
  int get currentIndex => _currentIndex;

  @visibleForTesting
  NativePlaybackMode get playbackMode => _playbackMode;

  Future<NativePlaybackMode> cyclePlaybackMode() async {
    await _restoreFuture;
    await setPlaybackMode(_playbackMode.nextMode);
    return _playbackMode;
  }

  Future<void> setPlaybackMode(NativePlaybackMode mode) async {
    await _restoreFuture;
    if (_playbackMode == mode) {
      return;
    }
    _playbackMode = mode;
    await _persistState();
    debugPrint('[native-audio] playback mode set: ${mode.storageValue}');
  }

  Future<bool> syncFromProbe(PlayerProbeSnapshot snapshot) async {
    await _restoreFuture;
    _syncQueue(snapshot);
    final String audioUrl = await _resolveAudioUrl(snapshot);
    if (audioUrl.isEmpty) {
      debugPrint(
        '[native-audio] probe ignored: no audio URL for ${snapshot.debugTitle}',
      );
      return false;
    }
    if (_loadedUrl != audioUrl) {
      _loadedUrl = audioUrl;
      _loadedSnapshot = snapshot;
      await _player.loadFromSnapshot(audioUrl, snapshot);
      if (snapshot.currentTime > Duration.zero) {
        await _player.seek(snapshot.currentTime);
      }
      debugPrint('[native-audio] loaded ${snapshot.debugTitle}');
      await _persistState();
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

  Future<void> syncQueueFromProbe(PlayerProbeSnapshot snapshot) async {
    await _restoreFuture;
    _syncQueue(snapshot);
  }

  Future<bool> resumePlayback() async {
    await _restoreFuture;
    if (_loadedUrl.isNotEmpty) {
      final PlayerProbeSnapshot? snapshot = _loadedSnapshot;
      if (_player.processingState == ProcessingState.idle && snapshot != null) {
        await _player.loadFromSnapshot(_loadedUrl, snapshot);
      }
      await _player.play();
      debugPrint(
        '[native-audio] resumed ${snapshot?.debugTitle ?? _loadedUrl}',
      );
      return true;
    }
    if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
      final bool handled = await _loadQueueIndex(_currentIndex);
      if (!handled) {
        debugPrint(
          '[native-audio] resume failed: current queue item could not load',
        );
      }
      return handled;
    }
    debugPrint('[native-audio] resume ignored: no loaded track or queue');
    return false;
  }

  Future<bool> skipToNext() async {
    await _restoreFuture;
    return _skipToQueueOffset(1);
  }

  Future<bool> skipToPrevious() async {
    await _restoreFuture;
    return _skipToQueueOffset(-1);
  }

  Future<bool> skipToQueueIndex(int index) async {
    await _restoreFuture;
    if (index < 0 || index >= _playlist.length) {
      debugPrint(
        '[native-audio] queue item ignored: index=$index '
        'length=${_playlist.length}',
      );
      return false;
    }
    return _loadQueueIndex(index);
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
      debugPrint('[native-audio] queue sync skipped: empty playlist');
      return;
    }
    _playlist = List<FreeMusicSong>.unmodifiable(snapshot.playlist);
    if (snapshot.currentIndex >= 0 &&
        snapshot.currentIndex < _playlist.length) {
      _currentIndex = snapshot.currentIndex;
      debugPrint(
        '[native-audio] queue synced: length=${_playlist.length} '
        'index=$_currentIndex',
      );
      unawaited(_persistState());
      return;
    }
    _currentIndex = _indexOfSong(snapshot.song);
    debugPrint(
      '[native-audio] queue synced: length=${_playlist.length} '
      'index=$_currentIndex',
    );
    unawaited(_persistState());
  }

  Future<bool> _skipToQueueOffset(int offset) async {
    if (_playlist.isEmpty || _currentIndex < 0) {
      debugPrint(
        '[native-audio] skip ignored: queue length=${_playlist.length} '
        'index=$_currentIndex offset=$offset',
      );
      return false;
    }
    final int targetIndex = _targetIndexForOffset(offset);
    if (targetIndex < 0) {
      debugPrint(
        '[native-audio] skip ignored: target=$targetIndex mode='
        '${_playbackMode.storageValue} length=${_playlist.length}',
      );
      return false;
    }
    return _loadQueueIndex(targetIndex);
  }

  int _targetIndexForOffset(int offset) {
    if (_playlist.isEmpty || _currentIndex < 0) {
      return -1;
    }
    if (_playbackMode == NativePlaybackMode.repeatOne) {
      return _currentIndex;
    }
    if (_playbackMode == NativePlaybackMode.shuffle && _playlist.length > 1) {
      int targetIndex = _random.nextInt(_playlist.length - 1);
      if (targetIndex >= _currentIndex) {
        targetIndex += 1;
      }
      return targetIndex;
    }
    final int targetIndex = _currentIndex + offset;
    if (targetIndex >= 0 && targetIndex < _playlist.length) {
      return targetIndex;
    }
    if (_playbackMode == NativePlaybackMode.repeatAll) {
      if (targetIndex < 0) {
        return _playlist.length - 1;
      }
      return 0;
    }
    return -1;
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
      debugPrint(
        '[native-audio] skip failed: no URL for ${snapshot.debugTitle}',
      );
      return false;
    }
    _currentIndex = index;
    _loadedUrl = audioUrl;
    _loadedSnapshot = snapshot;
    await _player.loadFromSnapshot(audioUrl, snapshot);
    await _player.play();
    await _persistState();
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

  Future<SharedPreferences> _getPreferences() async {
    return _preferences ?? SharedPreferences.getInstance();
  }

  Future<void> _restoreState() async {
    try {
      final SharedPreferences preferences = await _getPreferences();
      final String? raw = preferences.getString(_statePreferenceKey);
      if (raw == null || raw.isEmpty) {
        debugPrint('[native-audio] restore skipped: no saved state');
        return;
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('[native-audio] restore skipped: invalid saved state');
        return;
      }
      final List<FreeMusicSong> restoredPlaylist = _songsFromJson(
        decoded['playlist'],
      );
      final PlayerProbeSnapshot? restoredSnapshot = _snapshotFromJson(
        decoded['snapshot'],
        fallbackPlaylist: restoredPlaylist,
      );
      _playlist = List<FreeMusicSong>.unmodifiable(restoredPlaylist);
      _currentIndex = _intValue(decoded['currentIndex'], defaultValue: -1);
      _playbackMode = NativePlaybackMode.fromStorageValue(
        _stringValue(decoded['playbackMode']),
      );
      _loadedUrl = _stringValue(decoded['loadedUrl']);
      _loadedSnapshot = restoredSnapshot;
      if (_currentIndex < 0 && restoredSnapshot != null) {
        _currentIndex = _indexOfSong(restoredSnapshot.song);
      }
      debugPrint(
        '[native-audio] restored: loaded=${_loadedUrl.isNotEmpty} '
        'queue=${_playlist.length} index=$_currentIndex '
        'mode=${_playbackMode.storageValue}',
      );
    } catch (error, stackTrace) {
      debugPrint('[native-audio] restore failed: $error');
      if (kDebugMode) {
        debugPrint('$stackTrace');
      }
    }
  }

  Future<void> _persistState() async {
    try {
      if (_loadedUrl.isEmpty &&
          _playlist.isEmpty &&
          _playbackMode == NativePlaybackMode.sequential) {
        return;
      }
      final SharedPreferences preferences = await _getPreferences();
      final Map<String, Object?> payload = <String, Object?>{
        'loadedUrl': _loadedUrl,
        'currentIndex': _currentIndex,
        'playbackMode': _playbackMode.storageValue,
        'playlist': _playlist.map(_songToJson).toList(growable: false),
        'snapshot': _snapshotToJson(_loadedSnapshot),
      };
      await preferences.setString(_statePreferenceKey, jsonEncode(payload));
      debugPrint(
        '[native-audio] persisted: loaded=${_loadedUrl.isNotEmpty} '
        'queue=${_playlist.length} index=$_currentIndex '
        'mode=${_playbackMode.storageValue}',
      );
    } catch (error, stackTrace) {
      debugPrint('[native-audio] persist failed: $error');
      if (kDebugMode) {
        debugPrint('$stackTrace');
      }
    }
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

Map<String, Object?> _songToJson(FreeMusicSong song) {
  return <String, Object?>{
    'id': song.id,
    'source': song.source,
    'name': song.name,
    'artist': song.artist,
    'duration': song.duration,
  };
}

List<FreeMusicSong> _songsFromJson(Object? value) {
  if (value is! Iterable) {
    return const <FreeMusicSong>[];
  }
  return value
      .whereType<Map>()
      .map((Map<Object?, Object?> item) => _songFromMap(item))
      .where((FreeMusicSong song) => song.canResolve)
      .toList(growable: false);
}

FreeMusicSong _songFromMap(Map<Object?, Object?> item) {
  return FreeMusicSong(
    id: _stringValue(item['id']),
    source: _stringValue(item['source']),
    name: _stringValue(item['name'] ?? item['title']),
    artist: _stringValue(item['artist']),
    duration: _intValue(item['duration']),
  );
}

Map<String, Object?>? _snapshotToJson(PlayerProbeSnapshot? snapshot) {
  if (snapshot == null) {
    return null;
  }
  return <String, Object?>{
    'audioUrl': snapshot.audioUrl,
    'playing': snapshot.playing,
    'song': snapshot.song == null ? null : _songToJson(snapshot.song!),
    'playlist': snapshot.playlist.map(_songToJson).toList(growable: false),
    'currentIndex': snapshot.currentIndex,
    'title': snapshot.title,
    'artist': snapshot.artist,
    'coverUrl': snapshot.coverUrl,
    'currentTimeMs': snapshot.currentTime.inMilliseconds,
    'durationMs': snapshot.duration.inMilliseconds,
  };
}

PlayerProbeSnapshot? _snapshotFromJson(
  Object? value, {
  required List<FreeMusicSong> fallbackPlaylist,
}) {
  if (value is! Map) {
    return null;
  }
  final FreeMusicSong? song = value['song'] is Map
      ? _songFromMap((value['song'] as Map).cast<Object?, Object?>())
      : null;
  final List<FreeMusicSong> playlist = _songsFromJson(value['playlist']);
  return PlayerProbeSnapshot(
    audioUrl: _stringValue(value['audioUrl']),
    playing: value['playing'] == true,
    song: song,
    playlist: playlist.isEmpty ? fallbackPlaylist : playlist,
    currentIndex: _intValue(value['currentIndex'], defaultValue: -1),
    title: _stringValue(value['title'] ?? song?.name),
    artist: _stringValue(value['artist'] ?? song?.artist),
    coverUrl: _stringValue(value['coverUrl']),
    currentTime: Duration(milliseconds: _intValue(value['currentTimeMs'])),
    duration: Duration(milliseconds: _intValue(value['durationMs'])),
  );
}
