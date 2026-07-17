import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../free_music_api.dart';
import '../services/app_telemetry.dart';

abstract class MusicSearchClient {
  Future<FreeMusicSearchResult> searchSongs(
    String query, {
    int page = 0,
    List<String>? sources,
  });

  Future<FreeMusicRecommendResult> fetchRecommendations({
    List<String>? sources,
  });
}

class FreeMusicSearchApiClient implements MusicSearchClient {
  const FreeMusicSearchApiClient(this._api);

  final FreeMusicApi _api;

  @override
  Future<FreeMusicSearchResult> searchSongs(
    String query, {
    int page = 0,
    List<String>? sources,
  }) {
    return _api.searchSongs(query, page: page, sources: sources);
  }

  @override
  Future<FreeMusicRecommendResult> fetchRecommendations({
    List<String>? sources,
  }) {
    return _api.fetchRecommendations(sources: sources);
  }
}

class MusicSearchController extends ChangeNotifier {
  MusicSearchController({
    required MusicSearchClient client,
    AppTelemetry? telemetry,
    this.searchDebounce = const Duration(milliseconds: 300),
    SharedPreferences? preferences,
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _client = client,
       _telemetry = telemetry ?? AppTelemetry.instance,
       _preferences = preferences,
       _preferencesLoader = preferencesLoader;

  static const String _recommendationsCachePrefix = 'recommended_playlists_v1_';

  final MusicSearchClient _client;
  final AppTelemetry _telemetry;
  final Duration searchDebounce;
  final SharedPreferences? _preferences;
  final Future<SharedPreferences> Function()? _preferencesLoader;

  bool _isSearching = false;
  bool _isLoadingMore = false;
  bool _isLoadingRecommendations = false;
  int _searchRequestId = 0;
  int _searchPage = 0;
  bool _searchHasMore = false;
  String _searchError = '';
  String _searchLoadMoreError = '';
  String _recommendationError = '';
  String _lastSearchQuery = '';
  String _lastRecommendationSourceKey = '';
  List<FreeMusicSong> _searchResults = const <FreeMusicSong>[];
  List<FreeMusicPlaylist> _recommendedPlaylists = const <FreeMusicPlaylist>[];
  final Map<String, List<FreeMusicPlaylist>> _recommendationMemoryCache =
      <String, List<FreeMusicPlaylist>>{};
  Timer? _searchDebounceTimer;
  Completer<void>? _pendingDebouncedSearch;

  bool get isSearching => _isSearching;

  bool get isLoadingMore => _isLoadingMore;

  bool get isLoadingRecommendations => _isLoadingRecommendations;

  bool get searchHasMore => _searchHasMore;

  String get searchError => _searchError;

  String get searchLoadMoreError => _searchLoadMoreError;

  String get recommendationError => _recommendationError;

  String get lastSearchQuery => _lastSearchQuery;

  List<FreeMusicSong> get searchResults => _searchResults;

  List<FreeMusicPlaylist> get recommendedPlaylists => _recommendedPlaylists;

  /// Last catalog source key served from memory/disk/network.
  String get lastRecommendationSourceKey => _lastRecommendationSourceKey;

  Future<void> searchSongsDebounced(
    String query, {
    List<String>? sources,
  }) async {
    _searchDebounceTimer?.cancel();
    _completePendingDebouncedSearch();
    final String normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty || searchDebounce == Duration.zero) {
      await searchSongs(normalizedQuery, sources: sources);
      return;
    }
    final Completer<void> completer = Completer<void>();
    _pendingDebouncedSearch = completer;
    _searchDebounceTimer = Timer(searchDebounce, () {
      unawaited(
        searchSongs(
          normalizedQuery,
          sources: sources,
        ).whenComplete(() => _completePendingDebouncedSearch(completer)),
      );
    });
    return completer.future;
  }

  Future<void> searchSongs(String query, {List<String>? sources}) async {
    final String normalizedQuery = query.trim();
    final int requestId = ++_searchRequestId;
    if (normalizedQuery.isEmpty) {
      _resetSearch();
      return;
    }

    _isSearching = true;
    if (!_isLoadingMore) {
      _searchHasMore = false;
    }
    _isLoadingMore = false;
    _searchError = '';
    _searchLoadMoreError = '';
    _lastSearchQuery = normalizedQuery;
    _searchPage = 0;
    notifyListeners();

    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final FreeMusicSearchResult result = await _client.searchSongs(
        normalizedQuery,
        page: 0,
        sources: sources,
      );
      if (requestId != _searchRequestId) {
        return;
      }
      _searchResults = List<FreeMusicSong>.unmodifiable(result.songs);
      _searchPage = result.page;
      _searchHasMore = result.hasMore;
      _isSearching = false;
      _telemetry.record(
        'search_first_page',
        duration: stopwatch.elapsed,
        attributes: <String, Object?>{
          'queryLength': normalizedQuery.length,
          'sources': sources?.join(','),
          'resultCount': result.songs.length,
          'hasMore': result.hasMore,
        },
      );
      notifyListeners();
    } on FreeMusicApiException catch (error) {
      if (requestId != _searchRequestId) {
        return;
      }
      _searchError = error.message;
      _isSearching = false;
      _telemetry.record(
        'search_first_page.error',
        duration: stopwatch.elapsed,
        attributes: <String, Object?>{
          'queryLength': normalizedQuery.length,
          'sources': sources?.join(','),
        },
        error: error.message,
      );
      notifyListeners();
    } catch (error) {
      if (requestId != _searchRequestId) {
        return;
      }
      _searchError = '搜索失败：$error';
      _isSearching = false;
      _telemetry.record(
        'search_first_page.error',
        duration: stopwatch.elapsed,
        attributes: <String, Object?>{
          'queryLength': normalizedQuery.length,
          'sources': sources?.join(','),
        },
        error: error,
      );
      notifyListeners();
    }
  }

  Future<void> loadMoreSearchResults({List<String>? sources}) async {
    final String query = _lastSearchQuery.trim();
    if (query.isEmpty || !_searchHasMore || _isLoadingMore || _isSearching) {
      return;
    }
    final int requestId = _searchRequestId;
    _isLoadingMore = true;
    _searchLoadMoreError = '';
    notifyListeners();

    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final FreeMusicSearchResult result = await _client.searchSongs(
        query,
        page: _searchPage + 1,
        sources: sources,
      );
      if (requestId != _searchRequestId) {
        return;
      }
      _searchResults = List<FreeMusicSong>.unmodifiable(<FreeMusicSong>[
        ..._searchResults,
        ...result.songs,
      ]);
      _searchPage = result.page;
      _searchHasMore = result.hasMore;
      _isLoadingMore = false;
      _telemetry.record(
        'search_load_more',
        duration: stopwatch.elapsed,
        attributes: <String, Object?>{
          'queryLength': query.length,
          'page': result.page,
          'resultCount': result.songs.length,
          'hasMore': result.hasMore,
        },
      );
      notifyListeners();
    } on FreeMusicApiException catch (error) {
      if (requestId != _searchRequestId) {
        return;
      }
      _searchLoadMoreError = error.message;
      _isLoadingMore = false;
      _telemetry.record(
        'search_load_more.error',
        duration: stopwatch.elapsed,
        attributes: <String, Object?>{'queryLength': query.length},
        error: error.message,
      );
      notifyListeners();
    } catch (error) {
      if (requestId != _searchRequestId) {
        return;
      }
      _searchLoadMoreError = '加载更多失败：$error';
      _isLoadingMore = false;
      _telemetry.record(
        'search_load_more.error',
        duration: stopwatch.elapsed,
        attributes: <String, Object?>{'queryLength': query.length},
        error: error,
      );
      notifyListeners();
    }
  }

  Future<void> loadRecommendations({
    List<String>? sources,
    bool forceRefresh = false,
  }) async {
    final String sourceKey = _sourceKey(sources);

    // Spotify-like catalog cache: serve memory/disk immediately when the
    // requested source already has data. Never no-op just because another
    // source is mid-fetch — that made source chips feel stuck.
    if (!forceRefresh) {
      final List<FreeMusicPlaylist>? memory =
          _recommendationMemoryCache[sourceKey];
      if (memory != null && memory.isNotEmpty) {
        if (_lastRecommendationSourceKey != sourceKey ||
            !identical(_recommendedPlaylists, memory)) {
          _recommendedPlaylists = memory;
          _lastRecommendationSourceKey = sourceKey;
          _recommendationError = '';
          notifyListeners();
        }
        return;
      }
      // Disk read even while another source is loading: UI can switch instantly.
      final List<FreeMusicPlaylist>? disk = await _readRecommendationDiskCache(
        sourceKey,
      );
      if (disk != null && disk.isNotEmpty) {
        _recommendedPlaylists = disk;
        _recommendationMemoryCache[sourceKey] = disk;
        _lastRecommendationSourceKey = sourceKey;
        _recommendationError = '';
        notifyListeners();
        return;
      }
    }

    if (_isLoadingRecommendations) {
      // Another fetch in flight with no cache for this source: mark selected
      // source and clear stale playlists so the chip selection is visible.
      if (_lastRecommendationSourceKey != sourceKey) {
        _lastRecommendationSourceKey = sourceKey;
        _recommendedPlaylists = const <FreeMusicPlaylist>[];
        _recommendationError = '';
        notifyListeners();
      }
      return;
    }

    // Switching sources without cache: clear previous source's cards first.
    if (_lastRecommendationSourceKey != sourceKey) {
      _recommendedPlaylists = const <FreeMusicPlaylist>[];
      _recommendationError = '';
    }

    _isLoadingRecommendations = true;
    _lastRecommendationSourceKey = sourceKey;
    _recommendationError = '';
    notifyListeners();

    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final FreeMusicRecommendResult result = await _client
          .fetchRecommendations(sources: sources);
      // If user switched source while this request was in flight, still store
      // the result in cache but only publish when it matches the latest key.
      final List<FreeMusicPlaylist> playlists =
          List<FreeMusicPlaylist>.unmodifiable(result.playlists);
      _recommendationMemoryCache[sourceKey] = playlists;
      unawaited(_writeRecommendationDiskCache(sourceKey, playlists));
      if (_lastRecommendationSourceKey == sourceKey) {
        _recommendedPlaylists = playlists;
        _isLoadingRecommendations = false;
        _telemetry.record(
          'recommendations_load',
          duration: stopwatch.elapsed,
          attributes: <String, Object?>{
            'sources': sources?.join(','),
            'playlistCount': result.playlists.length,
            'forceRefresh': forceRefresh,
          },
        );
        notifyListeners();
      } else {
        _isLoadingRecommendations = false;
        notifyListeners();
      }
    } on FreeMusicApiException catch (error) {
      if (_lastRecommendationSourceKey == sourceKey) {
        _recommendationError = error.message;
      }
      _isLoadingRecommendations = false;
      _telemetry.record(
        'recommendations_load.error',
        duration: stopwatch.elapsed,
        attributes: <String, Object?>{'sources': sources?.join(',')},
        error: error.message,
      );
      notifyListeners();
    } catch (error) {
      final String msg = error.toString();
      if (_lastRecommendationSourceKey == sourceKey) {
        _recommendationError =
            msg.contains('TimeoutException') || msg.contains('timeout')
            ? '推荐加载超时，请检查网络后重试'
            : '推荐加载失败：$error';
      }
      _isLoadingRecommendations = false;
      _telemetry.record(
        'recommendations_load.error',
        duration: stopwatch.elapsed,
        attributes: <String, Object?>{'sources': sources?.join(',')},
        error: error,
      );
      notifyListeners();
    }
  }

  String _sourceKey(List<String>? sources) {
    if (sources == null || sources.isEmpty) {
      return 'default';
    }
    final List<String> sorted = List<String>.from(sources)..sort();
    return sorted.join(',');
  }

  Future<SharedPreferences> _prefs() async {
    final Future<SharedPreferences> Function()? loader = _preferencesLoader;
    if (loader != null) {
      return loader();
    }
    return _preferences ?? SharedPreferences.getInstance();
  }

  Future<List<FreeMusicPlaylist>?> _readRecommendationDiskCache(
    String sourceKey,
  ) async {
    try {
      final SharedPreferences prefs = await _prefs();
      final String? raw = prefs.getString(
        '$_recommendationsCachePrefix$sourceKey',
      );
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final Object? list = decoded['playlists'];
      if (list is! List) {
        return null;
      }
      final List<FreeMusicPlaylist> playlists = list
          .whereType<Map>()
          .map(
            (Map<dynamic, dynamic> item) => FreeMusicPlaylist.fromMap(
              item.map(
                (dynamic key, dynamic value) =>
                    MapEntry<String, dynamic>('$key', value),
              ),
            ),
          )
          .where((FreeMusicPlaylist p) => p.canLoad)
          .toList(growable: false);
      return List<FreeMusicPlaylist>.unmodifiable(playlists);
    } catch (error) {
      debugPrint('[search] recommendation cache read failed: $error');
      return null;
    }
  }

  Future<void> _writeRecommendationDiskCache(
    String sourceKey,
    List<FreeMusicPlaylist> playlists,
  ) async {
    try {
      final SharedPreferences prefs = await _prefs();
      final String payload = jsonEncode(<String, Object?>{
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'playlists': playlists
            .map((FreeMusicPlaylist p) => p.toMap())
            .toList(growable: false),
      });
      await prefs.setString(
        '$_recommendationsCachePrefix$sourceKey',
        payload,
      );
    } catch (error) {
      debugPrint('[search] recommendation cache write failed: $error');
    }
  }

  /// Drops recommendation memory+disk cache (settings / storage cleanup).
  Future<void> clearRecommendationCache() async {
    _recommendationMemoryCache.clear();
    try {
      final SharedPreferences prefs = await _prefs();
      final Iterable<String> keys = prefs
          .getKeys()
          .where((String key) => key.startsWith(_recommendationsCachePrefix));
      for (final String key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _completePendingDebouncedSearch();
    super.dispose();
  }

  void _resetSearch() {
    _lastSearchQuery = '';
    _searchError = '';
    _searchLoadMoreError = '';
    _searchResults = const <FreeMusicSong>[];
    _searchPage = 0;
    _searchHasMore = false;
    _isSearching = false;
    _isLoadingMore = false;
    notifyListeners();
  }

  void _completePendingDebouncedSearch([Completer<void>? completer]) {
    final Completer<void>? target = completer ?? _pendingDebouncedSearch;
    if (target != null && !target.isCompleted) {
      target.complete();
    }
    if (identical(_pendingDebouncedSearch, target)) {
      _pendingDebouncedSearch = null;
    }
  }
}
