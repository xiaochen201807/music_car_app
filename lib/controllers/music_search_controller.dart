import 'dart:async';

import 'package:flutter/foundation.dart';

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
  }) : _client = client,
       _telemetry = telemetry ?? AppTelemetry.instance;

  final MusicSearchClient _client;
  final AppTelemetry _telemetry;
  final Duration searchDebounce;

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
  List<FreeMusicSong> _searchResults = const <FreeMusicSong>[];
  List<FreeMusicPlaylist> _recommendedPlaylists = const <FreeMusicPlaylist>[];
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

  Future<void> loadRecommendations({List<String>? sources}) async {
    if (_isLoadingRecommendations) {
      return;
    }
    _isLoadingRecommendations = true;
    _recommendationError = '';
    notifyListeners();

    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final FreeMusicRecommendResult result = await _client
          .fetchRecommendations(sources: sources);
      _recommendedPlaylists = List<FreeMusicPlaylist>.unmodifiable(
        result.playlists,
      );
      _isLoadingRecommendations = false;
      _telemetry.record(
        'recommendations_load',
        duration: stopwatch.elapsed,
        attributes: <String, Object?>{
          'sources': sources?.join(','),
          'playlistCount': result.playlists.length,
        },
      );
      notifyListeners();
    } on FreeMusicApiException catch (error) {
      _recommendationError = error.message;
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
      _recommendationError =
          msg.contains('TimeoutException') || msg.contains('timeout')
          ? '推荐加载超时，请检查网络后重试'
          : '推荐加载失败：$error';
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
