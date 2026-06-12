import 'package:flutter/foundation.dart';

import '../free_music_api.dart';

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
  MusicSearchController({required MusicSearchClient client}) : _client = client;

  final MusicSearchClient _client;

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
      notifyListeners();
    } on FreeMusicApiException catch (error) {
      if (requestId != _searchRequestId) {
        return;
      }
      _searchError = error.message;
      _isSearching = false;
      notifyListeners();
    } catch (error) {
      if (requestId != _searchRequestId) {
        return;
      }
      _searchError = '搜索失败：$error';
      _isSearching = false;
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
      notifyListeners();
    } on FreeMusicApiException catch (error) {
      if (requestId != _searchRequestId) {
        return;
      }
      _searchLoadMoreError = error.message;
      _isLoadingMore = false;
      notifyListeners();
    } catch (error) {
      if (requestId != _searchRequestId) {
        return;
      }
      _searchLoadMoreError = '加载更多失败：$error';
      _isLoadingMore = false;
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

    try {
      final FreeMusicRecommendResult result = await _client
          .fetchRecommendations(sources: sources);
      _recommendedPlaylists = List<FreeMusicPlaylist>.unmodifiable(
        result.playlists,
      );
      _isLoadingRecommendations = false;
      notifyListeners();
    } on FreeMusicApiException catch (error) {
      _recommendationError = error.message;
      _isLoadingRecommendations = false;
      notifyListeners();
    } catch (error) {
      final String msg = error.toString();
      _recommendationError =
          msg.contains('TimeoutException') || msg.contains('timeout')
          ? '推荐加载超时，请检查网络后重试'
          : '推荐加载失败：$error';
      _isLoadingRecommendations = false;
      notifyListeners();
    }
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
}
