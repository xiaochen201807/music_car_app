import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'free_music_api.dart';
import 'models/cached_track.dart';
import 'services/app_settings_controller.dart';
import 'services/download_service.dart';

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
    return NativePlaybackMode.repeatAll;
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
        cover: _stringValue(payload['coverUrl'] ?? payload['cover']),
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

  Future<void> setVolume(double volume);

  Future<void> play();

  Future<void> playDirect();

  Future<void> pause();

  Future<void> pauseDirect();

  Future<void> stop();

  Future<void> dispose();
}

class JustAudioNativePlayer implements NativeAudioPlayer {
  JustAudioNativePlayer({AudioPlayer? player})
    : _player =
          player ??
          AudioPlayer(
            audioLoadConfiguration: AudioLoadConfiguration(
              androidLoadControl: AndroidLoadControl(
                maxBufferDuration: const Duration(seconds: 60),
                targetBufferBytes: 50 * 1024 * 1024, // 50MB
              ),
            ),
          );

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
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> playDirect() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> pauseDirect() => _player.pause();

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
    DownloadService? downloadService,
  }) : _player = player ?? JustAudioNativePlayer(),
       _api = api ?? FreeMusicApi(),
       _downloadService = downloadService,
       _preferences = preferences {
    _updatePlaybackContext();
    _restoreFuture = _restoreState();
  }

  static const String _statePreferenceKey = 'native_audio_state_v1';

  final NativeAudioPlayer _player;
  final FreeMusicApi _api;
  final DownloadService? _downloadService;
  final SharedPreferences? _preferences;
  late final Future<void> _restoreFuture;
  String _loadedUrl = '';
  PlayerProbeSnapshot? _loadedSnapshot;
  List<FreeMusicSong> _playlist = const <FreeMusicSong>[];
  int _currentIndex = -1;
  NativePlaybackMode _playbackMode = NativePlaybackMode.repeatAll;
  final math.Random _random = math.Random();
  bool _isQueueLoading = false;
  bool _wantsPlayback = false;
  Timer? _persistTimer;
  late PlaybackQueueContext _currentContext;

  /// Alternate sources for the source-switch fallback, fetched lazily once.
  List<String>? _cachedSources;
  static const List<String> _fallbackSources = <String>['netease', 'kuwo'];

  /// 预加载缓存：下一首歌曲的 URL
  String? _preloadedNextUrl;
  int? _preloadedNextIndex;

  List<FreeMusicSong> get playlist => _playlist;

  int get currentIndex => _currentIndex;

  bool get playing => _player.playing;

  Duration get position => _player.position;

  Future<void> seek(Duration position) async {
    // 仅给 loading 状态一次极短等待（100ms），避免自旋阻塞 UI
    if (_player.processingState == ProcessingState.loading) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('[native-audio] seek failed: $e, retrying once in 200ms...');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      try {
        await _player.seek(position);
      } catch (_) {}
    }
  }

  PlaybackQueueContext getPlaybackContext() {
    return _currentContext;
  }

  Future<void> flush() => _persistState(immediate: true);

  /// Waits for the restore-state future to complete. Call this before reading
  /// [playlist] or [currentIndex] to ensure persisted data has been loaded.
  Future<void> waitForRestore() => _restoreFuture;

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
    await _persistState(immediate: true);
    debugPrint('[native-audio] playback mode set: ${mode.storageValue}');
  }

  Future<bool> syncFromProbe(PlayerProbeSnapshot snapshot) async {
    await _restoreFuture;
    _syncQueue(snapshot);
    _wantsPlayback = snapshot.playing;
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
      await _persistState(immediate: true);
    }
    if (snapshot.playing) {
      await _player.playDirect();
      debugPrint('[native-audio] playing ${snapshot.debugTitle}');
    } else {
      await _player.pauseDirect();
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
    _wantsPlayback = true;
    if (_isQueueLoading) {
      debugPrint('[native-audio] resume queued while track is loading');
      return true;
    }
    if (_loadedUrl.isNotEmpty) {
      final PlayerProbeSnapshot? snapshot = _loadedSnapshot;
      if (_player.processingState == ProcessingState.idle && snapshot != null) {
        await _player.loadFromSnapshot(_loadedUrl, snapshot);
      }
      await _player.playDirect();
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

  Future<bool> pausePlayback() async {
    await _restoreFuture;
    _wantsPlayback = false;
    if (_loadedUrl.isEmpty && _currentIndex < 0) {
      debugPrint('[native-audio] pause ignored: no loaded track or queue');
      return false;
    }
    await _player.pauseDirect();
    debugPrint(
      '[native-audio] paused ${_loadedSnapshot?.debugTitle ?? _loadedUrl}',
    );
    return true;
  }

  Future<bool> playSong(FreeMusicSong song) async {
    await _restoreFuture;
    final PlayerProbeSnapshot snapshot = PlayerProbeSnapshot(
      audioUrl: '',
      playing: true,
      song: song,
      title: song.name,
      artist: song.artist,
      coverUrl: song.cover,
      duration: Duration(seconds: song.duration),
    );
    return syncFromProbe(snapshot);
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
    return _loadQueueIndex(index, playWhenReady: true);
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> dispose() async {
    _persistTimer?.cancel();
    await _performPersist();
    _api.close();
    await _player.dispose();
  }

  Future<String> getPreferredBitrate() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(preferredBitratePreferenceKey) ??
          defaultPreferredBitrate;
    } catch (_) {
      return defaultPreferredBitrate;
    }
  }

  Future<String> _resolveAudioUrl(PlayerProbeSnapshot snapshot) async {
    final FreeMusicSong? song = snapshot.song;
    if (song != null && song.canResolve) {
      final DownloadService? ds = _downloadService;
      if (ds != null && ds.isDownloaded(song.source, song.id)) {
        final CachedTrack? cached = ds.getCachedTrack(song.source, song.id);
        if (cached != null) {
          final String physicalPath = await ds.getPhysicalPath(cached);
          if (await File(physicalPath).exists()) {
            debugPrint(
              '[native-audio] cache hit for ${snapshot.debugTitle}, playing local file',
            );
            return physicalPath;
          } else {
            unawaited(ds.deleteTrack(song.source, song.id));
          }
        }
      }
    }

    if (snapshot.hasAudioUrl) {
      return snapshot.audioUrl;
    }
    if (song == null || !song.canResolve) {
      return '';
    }
    // Primary attempt on the song's own source. A failure here (HTTP error,
    // timeout, or an empty/unusable URL) must NOT bubble up as an unhandled
    // exception: a dead source would otherwise make playback — and any CarLife
    // projection reading this same queue — silently stall. We fall through to
    // [_resolveViaSourceSwitch] instead.
    final String preferredBitrate = await getPreferredBitrate();
    try {
      final FreeMusicResolvedUrl? resolved = await _api
          .resolveSongUrl(song, bitrate: preferredBitrate)
          .timeout(const Duration(seconds: 5));
      final String url = resolved?.url ?? '';
      if (url.isNotEmpty) {
        debugPrint('[native-audio] resolved ${snapshot.debugTitle}');
        return url;
      }
      debugPrint(
        '[native-audio] resolve empty for ${snapshot.debugTitle}, '
        'trying source switch',
      );
    } catch (error) {
      debugPrint(
        '[native-audio] resolve failed for ${snapshot.debugTitle}: $error, '
        'trying source switch',
      );
    }
    return _resolveViaSourceSwitch(song, snapshot);
  }

  /// Fallback when the song's own source cannot produce a playable URL. Asks
  /// the server for the same track on each alternate source and resolves a URL
  /// there. Best-effort: any failure (no candidate sources, no match, alternate
  /// source also dead) returns an empty string, which callers already treat as
  /// "could not play" rather than crashing.
  Future<String> _resolveViaSourceSwitch(
    FreeMusicSong song,
    PlayerProbeSnapshot snapshot,
  ) async {
    final List<String> targets = await _candidateSources();
    for (final String target in targets) {
      if (target == song.source) {
        continue;
      }
      try {
        final FreeMusicSourceSwitch? matched = await _api
            .switchSource(song, target: target)
            .timeout(const Duration(seconds: 5));
        if (matched == null) {
          continue;
        }
        final FreeMusicResolvedUrl? resolved = await _api
            .resolveSongUrl(matched.song)
            .timeout(const Duration(seconds: 5));
        final String url = resolved?.url ?? '';
        if (url.isNotEmpty) {
          debugPrint(
            '[native-audio] resolved ${snapshot.debugTitle} via $target '
            '(score ${matched.score.toStringAsFixed(2)})',
          );
          return url;
        }
      } catch (error) {
        debugPrint('[native-audio] source switch to $target failed: $error');
      }
    }
    return '';
  }

  /// Alternate sources to try when the primary source fails, fetched once and
  /// cached. Falls back to a static list if `/sources` is unavailable so the
  /// switch path still works offline-of-that-endpoint.
  Future<List<String>> _candidateSources() async {
    final List<String>? cached = _cachedSources;
    if (cached != null) {
      return cached;
    }
    List<String> sources;
    try {
      final FreeMusicSources fetched = await _api.fetchSources().timeout(
        const Duration(seconds: 5),
      );
      sources = fetched.allSources.isNotEmpty
          ? fetched.allSources
          : _fallbackSources;
    } catch (_) {
      sources = _fallbackSources;
    }
    _cachedSources = sources;
    return sources;
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
      _updatePlaybackContext();
      unawaited(_persistState());
      return;
    }
    _currentIndex = _indexOfSong(snapshot.song);
    debugPrint(
      '[native-audio] queue synced: length=${_playlist.length} '
      'index=$_currentIndex',
    );
    _updatePlaybackContext();
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
    return _loadQueueIndex(
      targetIndex,
      playWhenReady: _wantsPlayback || _player.playing,
    );
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

  /// 获取下一首的索引（用于预加载）
  int _getNextIndex() {
    return _targetIndexForOffset(1);
  }

  Future<void> _fadeOut(Duration duration) async {
    const int steps = 10;
    final int intervalMs = (duration.inMilliseconds / steps).round();
    for (int i = steps; i >= 0; i--) {
      final double vol = i / steps;
      await _player.setVolume(vol);
      await Future<void>.delayed(Duration(milliseconds: intervalMs));
    }
  }

  Future<void> _fadeIn(Duration duration) async {
    const int steps = 10;
    final int intervalMs = (duration.inMilliseconds / steps).round();
    for (int i = 0; i <= steps; i++) {
      final double vol = i / steps;
      await _player.setVolume(vol);
      await Future<void>.delayed(Duration(milliseconds: intervalMs));
    }
  }

  Future<bool> _loadQueueIndex(int index, {bool? playWhenReady}) async {
    if (!await _waitForQueueLoadSlot()) {
      debugPrint('[native-audio] queue load timed out before index=$index');
      return false;
    }
    _wantsPlayback = playWhenReady ?? _wantsPlayback;
    _isQueueLoading = true;
    try {
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
        coverUrl: song.cover,
        duration: Duration(seconds: song.duration),
      );

      // 检查是否有预加载的 URL
      String audioUrl = '';
      if (_preloadedNextIndex == index && _preloadedNextUrl != null) {
        audioUrl = _preloadedNextUrl!;
        debugPrint(
          '[native-audio] using preloaded URL for ${snapshot.debugTitle}',
        );
        _preloadedNextUrl = null;
        _preloadedNextIndex = null;
      } else {
        audioUrl = await _resolveAudioUrl(snapshot);
      }

      if (audioUrl.isEmpty) {
        debugPrint(
          '[native-audio] skip failed: no URL for ${snapshot.debugTitle}',
        );
        return false;
      }

      final bool wasPlaying = _player.playing;
      if (wasPlaying) {
        await _fadeOut(const Duration(milliseconds: 250));
      }

      await _player.setVolume(_wantsPlayback ? 0.0 : 1.0);

      _currentIndex = index;
      _updatePlaybackContext();
      _loadedUrl = audioUrl;
      _loadedSnapshot = snapshot;
      await _player.loadFromSnapshot(audioUrl, snapshot);
      if (_wantsPlayback) {
        await _player.playDirect();
      } else {
        await _player.pauseDirect();
      }
      await _persistState(immediate: true);
      debugPrint('[native-audio] skipped to ${snapshot.debugTitle}');

      if (_wantsPlayback) {
        await _fadeIn(const Duration(milliseconds: 250));
      } else {
        await _player.setVolume(1.0);
      }

      // 预加载下一首歌曲的 URL
      unawaited(_preloadNextSong());

      return true;
    } finally {
      _isQueueLoading = false;
    }
  }

  Future<bool> _waitForQueueLoadSlot() async {
    if (!_isQueueLoading) {
      return true;
    }
    debugPrint('[native-audio] queue operation busy, waiting');
    for (int attempt = 0; attempt < 80; attempt += 1) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!_isQueueLoading) {
        return true;
      }
    }
    return false;
  }

  /// 预加载下一首歌曲的 URL，减少切歌延迟
  Future<void> _preloadNextSong() async {
    final int nextIndex = _getNextIndex();
    if (nextIndex < 0 || nextIndex >= _playlist.length) {
      return;
    }

    final FreeMusicSong nextSong = _playlist[nextIndex];
    if (!nextSong.canResolve) {
      return;
    }

    try {
      final PlayerProbeSnapshot snapshot = PlayerProbeSnapshot(
        audioUrl: '',
        playing: false,
        song: nextSong,
        playlist: _playlist,
        currentIndex: nextIndex,
        title: nextSong.name,
        artist: nextSong.artist,
        coverUrl: nextSong.cover,
        duration: Duration(seconds: nextSong.duration),
      );
      final String url = await _resolveAudioUrl(snapshot);
      if (url.isNotEmpty) {
        _preloadedNextUrl = url;
        _preloadedNextIndex = nextIndex;
        debugPrint('[native-audio] preloaded next: ${nextSong.name}');
      }
    } catch (e) {
      debugPrint('[native-audio] preload failed: $e');
    }
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
      _updatePlaybackContext();
    } catch (error, stackTrace) {
      debugPrint('[native-audio] restore failed: $error');
      if (kDebugMode) {
        debugPrint('$stackTrace');
      }
    }
  }

  Future<void> _persistState({bool immediate = false}) async {
    if (immediate) {
      _persistTimer?.cancel();
      await _performPersist();
      return;
    }
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(_performPersist());
    });
  }

  Future<void> _performPersist() async {
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

  void _updatePlaybackContext() {
    _currentContext = PlaybackQueueContext(
      currentIndex: _currentIndex,
      playlist: List<FreeMusicSong>.unmodifiable(_playlist),
    );
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
          album: _stringValue(item['album']),
          cover: _stringValue(item['cover'] ?? item['coverUrl']),
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
    'album': song.album,
    'cover': song.cover,
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
    album: _stringValue(item['album']),
    cover: _stringValue(item['cover'] ?? item['coverUrl']),
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

class PlaybackQueueContext {
  const PlaybackQueueContext({
    required this.currentIndex,
    required this.playlist,
  });
  final int currentIndex;
  final List<FreeMusicSong> playlist;
}
