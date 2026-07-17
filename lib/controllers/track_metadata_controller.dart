import 'package:flutter/foundation.dart';

import '../free_music_api.dart';
import '../services/lru_cache.dart';

abstract class TrackMetadataClient {
  Future<FreeMusicLyrics> fetchEnhancedLyrics(FreeMusicSong song);

  Future<FreeMusicQualityResult> fetchQualities(FreeMusicSong song);
}

class FreeMusicTrackMetadataClient implements TrackMetadataClient {
  const FreeMusicTrackMetadataClient(this._api);

  final FreeMusicApi _api;

  @override
  Future<FreeMusicLyrics> fetchEnhancedLyrics(FreeMusicSong song) {
    return _api.fetchEnhancedLyrics(song).timeout(const Duration(seconds: 5));
  }

  @override
  Future<FreeMusicQualityResult> fetchQualities(FreeMusicSong song) {
    return _api.fetchQualities(song).timeout(const Duration(seconds: 5));
  }
}

class TrackMetadataController extends ChangeNotifier {
  TrackMetadataController({
    required TrackMetadataClient client,
    int lyricsCacheCapacity = 48,
  }) : _client = client,
       _lyricsCache = LruCache<String, FreeMusicLyrics>(
         capacity: lyricsCacheCapacity,
       );

  final TrackMetadataClient _client;
  final LruCache<String, FreeMusicLyrics> _lyricsCache;
  final Map<String, Future<FreeMusicLyrics>> _lyricsInflight =
      <String, Future<FreeMusicLyrics>>{};

  bool _isLoadingLyrics = false;
  bool _isLoadingQualities = false;
  int _lyricsRequestId = 0;
  int _qualitiesRequestId = 0;
  String _lyricsError = '';
  String _qualityError = '';
  FreeMusicLyrics? _currentLyrics;
  String _currentLyricsKey = '';
  List<FreeMusicQuality> _currentQualities = const <FreeMusicQuality>[];

  bool get isLoadingLyrics => _isLoadingLyrics;
  bool get isLoadingQualities => _isLoadingQualities;
  String get lyricsError => _lyricsError;
  String get qualityError => _qualityError;
  FreeMusicLyrics? get currentLyrics => _currentLyrics;
  String get currentLyricsKey => _currentLyricsKey;
  static String lyricsKeyFor(FreeMusicSong song) => '${song.source}:${song.id}';
  List<FreeMusicQuality> get currentQualities => _currentQualities;

  void reset() {
    _lyricsRequestId += 1;
    _qualitiesRequestId += 1;
    _isLoadingLyrics = false;
    _isLoadingQualities = false;
    _lyricsError = '';
    _qualityError = '';
    _currentLyrics = null;
    _currentLyricsKey = '';
    _currentQualities = const <FreeMusicQuality>[];
    notifyListeners();
  }

  Future<void> prefetchLyricsForSong(FreeMusicSong song) async {
    if (!song.canResolve) {
      return;
    }
    final String songKey = lyricsKeyFor(song);
    if (_lyricsCache.containsKey(songKey)) {
      return;
    }
    try {
      await _fetchLyricsCached(song);
    } catch (error) {
      debugPrint('[lyrics] prefetch failed for $songKey: $error');
    }
  }

  Future<bool> loadLyricsForSong(FreeMusicSong song) async {
    final int requestId = ++_lyricsRequestId;
    final String songKey = lyricsKeyFor(song);
    if (!song.canResolve) {
      _isLoadingLyrics = false;
      _lyricsError = '';
      _currentLyrics = null;
      _currentLyricsKey = '';
      notifyListeners();
      return true;
    }

    final FreeMusicLyrics? cached = _lyricsCache.get(songKey);
    if (cached != null) {
      _currentLyrics = cached;
      _currentLyricsKey = songKey;
      _lyricsError = '';
      _isLoadingLyrics = false;
      notifyListeners();
      return true;
    }

    _isLoadingLyrics = true;
    _lyricsError = '';
    _currentLyrics = null;
    _currentLyricsKey = '';
    notifyListeners();

    try {
      final FreeMusicLyrics lyrics = await _fetchLyricsCached(song);
      if (requestId != _lyricsRequestId) {
        return false;
      }
      _currentLyrics = lyrics;
      _currentLyricsKey = songKey;
      _isLoadingLyrics = false;
      notifyListeners();
      return true;
    } on FreeMusicApiException catch (error) {
      if (requestId != _lyricsRequestId) {
        return false;
      }
      _lyricsError = error.message;
      _currentLyrics = null;
      _currentLyricsKey = '';
      _isLoadingLyrics = false;
      notifyListeners();
      return true;
    } catch (error) {
      if (requestId != _lyricsRequestId) {
        return false;
      }
      _lyricsError = '歌词加载失败：$error';
      _currentLyrics = null;
      _currentLyricsKey = '';
      _isLoadingLyrics = false;
      notifyListeners();
      return true;
    }
  }

  Future<FreeMusicLyrics> _fetchLyricsCached(FreeMusicSong song) {
    final String songKey = lyricsKeyFor(song);
    final FreeMusicLyrics? cached = _lyricsCache.get(songKey);
    if (cached != null) {
      return Future<FreeMusicLyrics>.value(cached);
    }
    final Future<FreeMusicLyrics>? inflight = _lyricsInflight[songKey];
    if (inflight != null) {
      return inflight;
    }
    final Future<FreeMusicLyrics> future = _client
        .fetchEnhancedLyrics(song)
        .then((FreeMusicLyrics lyrics) {
          _lyricsCache.put(songKey, lyrics);
          return lyrics;
        })
        .whenComplete(() {
          _lyricsInflight.remove(songKey);
        });
    _lyricsInflight[songKey] = future;
    return future;
  }

  Future<bool> loadQualitiesForSong(FreeMusicSong song) async {
    if (!song.canResolve) {
      return false;
    }
    final int requestId = ++_qualitiesRequestId;
    _isLoadingQualities = true;
    _qualityError = '';
    _currentQualities = const <FreeMusicQuality>[];
    notifyListeners();

    try {
      final FreeMusicQualityResult result = await _client.fetchQualities(song);
      if (requestId != _qualitiesRequestId) {
        return false;
      }
      _currentQualities = List<FreeMusicQuality>.unmodifiable(result.qualities);
      _isLoadingQualities = false;
      notifyListeners();
      return true;
    } on FreeMusicApiException catch (error) {
      if (requestId != _qualitiesRequestId) {
        return false;
      }
      _qualityError = error.message;
      _isLoadingQualities = false;
      notifyListeners();
      return true;
    } catch (error) {
      if (requestId != _qualitiesRequestId) {
        return false;
      }
      _qualityError = '音质加载失败：$error';
      _isLoadingQualities = false;
      notifyListeners();
      return true;
    }
  }

  void clearLyricsCache() {
    _lyricsCache.clear();
    _lyricsInflight.clear();
  }
}
