import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_car_app/controllers/music_search_controller.dart';
import 'package:music_car_app/free_music_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  test('empty search resets query, results, paging, and errors', () async {
    final _FakeMusicSearchClient client = _FakeMusicSearchClient();
    final MusicSearchController controller = MusicSearchController(
      client: client,
    );
    client.searchResults.add(
      const FreeMusicSearchResult(
        songs: <FreeMusicSong>[],
        hasMore: true,
        page: 0,
      ),
    );
    await controller.searchSongs('jay');

    await controller.searchSongs('   ');

    expect(controller.lastSearchQuery, isEmpty);
    expect(controller.searchResults, isEmpty);
    expect(controller.searchHasMore, isFalse);
    expect(controller.isSearching, isFalse);
    expect(controller.isLoadingMore, isFalse);

    controller.dispose();
  });

  test('search exposes loading state and immutable results', () async {
    final Completer<FreeMusicSearchResult> completer =
        Completer<FreeMusicSearchResult>();
    final _FakeMusicSearchClient client = _FakeMusicSearchClient(
      onSearch: (_) => completer.future,
    );
    final MusicSearchController controller = MusicSearchController(
      client: client,
    );
    final List<bool> loadingStates = <bool>[];
    controller.addListener(() {
      loadingStates.add(controller.isSearching);
    });

    final Future<void> searchFuture = controller.searchSongs(
      '七里香',
      sources: const <String>['kuwo'],
    );
    expect(controller.isSearching, isTrue);
    expect(client.searchCalls.single.query, '七里香');
    expect(client.searchCalls.single.sources, <String>['kuwo']);

    final FreeMusicSong song = _song('1');
    completer.complete(
      FreeMusicSearchResult(
        songs: <FreeMusicSong>[song],
        hasMore: true,
        page: 0,
      ),
    );
    await searchFuture;

    expect(controller.isSearching, isFalse);
    expect(controller.searchResults, <FreeMusicSong>[song]);
    expect(controller.searchHasMore, isTrue);
    expect(
      () => controller.searchResults.add(_song('2')),
      throwsUnsupportedError,
    );
    expect(loadingStates, <bool>[true, false]);

    controller.dispose();
  });

  test('stale search result cannot overwrite a newer query', () async {
    final Completer<FreeMusicSearchResult> first =
        Completer<FreeMusicSearchResult>();
    final Completer<FreeMusicSearchResult> second =
        Completer<FreeMusicSearchResult>();
    int callCount = 0;
    final _FakeMusicSearchClient client = _FakeMusicSearchClient(
      onSearch: (_) {
        callCount += 1;
        return callCount == 1 ? first.future : second.future;
      },
    );
    final MusicSearchController controller = MusicSearchController(
      client: client,
    );

    final Future<void> firstFuture = controller.searchSongs('old');
    final Future<void> secondFuture = controller.searchSongs('new');
    final FreeMusicSong newSong = _song('2');
    second.complete(
      FreeMusicSearchResult(
        songs: <FreeMusicSong>[newSong],
        hasMore: false,
        page: 0,
      ),
    );
    await secondFuture;
    first.complete(
      FreeMusicSearchResult(
        songs: <FreeMusicSong>[_song('1')],
        hasMore: true,
        page: 0,
      ),
    );
    await firstFuture;

    expect(controller.lastSearchQuery, 'new');
    expect(controller.searchResults, <FreeMusicSong>[newSong]);
    expect(controller.searchHasMore, isFalse);

    controller.dispose();
  });

  test('debounced search only executes the latest query', () async {
    final _FakeMusicSearchClient client = _FakeMusicSearchClient();
    final MusicSearchController controller = MusicSearchController(
      client: client,
      searchDebounce: const Duration(milliseconds: 10),
    );
    client.searchResults.add(
      FreeMusicSearchResult(
        songs: <FreeMusicSong>[_song('2')],
        hasMore: false,
        page: 0,
      ),
    );

    final Future<void> first = controller.searchSongsDebounced('old');
    final Future<void> second = controller.searchSongsDebounced('new');

    await first;
    await second;

    expect(client.searchCalls, hasLength(1));
    expect(client.searchCalls.single.query, 'new');
    expect(controller.searchResults.single.id, '2');

    controller.dispose();
  });

  test('loadMore appends the next page and keeps original query', () async {
    final _FakeMusicSearchClient client = _FakeMusicSearchClient();
    final MusicSearchController controller = MusicSearchController(
      client: client,
    );
    final FreeMusicSong first = _song('1');
    final FreeMusicSong second = _song('2');
    client.searchResults.addAll(<FreeMusicSearchResult>[
      FreeMusicSearchResult(
        songs: <FreeMusicSong>[first],
        hasMore: true,
        page: 0,
      ),
      FreeMusicSearchResult(
        songs: <FreeMusicSong>[second],
        hasMore: false,
        page: 1,
      ),
    ]);

    await controller.searchSongs('road');
    await controller.loadMoreSearchResults();

    expect(controller.searchResults, <FreeMusicSong>[first, second]);
    expect(controller.searchHasMore, isFalse);
    expect(client.searchCalls.last.query, 'road');
    expect(client.searchCalls.last.page, 1);

    controller.dispose();
  });

  test('api errors map to search and load-more error fields', () async {
    final _FakeMusicSearchClient client = _FakeMusicSearchClient();
    final MusicSearchController controller = MusicSearchController(
      client: client,
    );
    client.searchErrors.add(const FreeMusicApiException('HTTP 500'));

    await controller.searchSongs('broken');

    expect(controller.searchError, 'HTTP 500');
    expect(controller.isSearching, isFalse);

    client.searchResults.add(
      FreeMusicSearchResult(
        songs: <FreeMusicSong>[_song('1')],
        hasMore: true,
        page: 0,
      ),
    );
    await controller.searchSongs('ok');
    client.searchErrors.add(StateError('network'));

    await controller.loadMoreSearchResults();

    expect(controller.searchLoadMoreError, contains('加载更多失败'));
    expect(controller.isLoadingMore, isFalse);

    controller.dispose();
  });

  test('recommendations load playlists and map timeout errors', () async {
    final _FakeMusicSearchClient client = _FakeMusicSearchClient();
    final MusicSearchController controller = MusicSearchController(
      client: client,
    );
    final FreeMusicPlaylist playlist = _playlist('1');
    client.recommendResults.add(
      FreeMusicRecommendResult(playlists: <FreeMusicPlaylist>[playlist]),
    );

    await controller.loadRecommendations(sources: const <String>['netease']);

    expect(controller.recommendedPlaylists, <FreeMusicPlaylist>[playlist]);
    expect(client.recommendCalls.single, <String>['netease']);

    client.recommendErrors.add(TimeoutException('slow'));
    await controller.loadRecommendations();

    expect(controller.recommendationError, '推荐加载超时，请检查网络后重试');
    expect(controller.isLoadingRecommendations, isFalse);

    controller.dispose();
  });
}

class _FakeMusicSearchClient implements MusicSearchClient {
  _FakeMusicSearchClient({this.onSearch});

  final Future<FreeMusicSearchResult> Function(_SearchCall call)? onSearch;
  final List<_SearchCall> searchCalls = <_SearchCall>[];
  final List<List<String>?> recommendCalls = <List<String>?>[];
  final List<FreeMusicSearchResult> searchResults = <FreeMusicSearchResult>[];
  final List<Object> searchErrors = <Object>[];
  final List<FreeMusicRecommendResult> recommendResults =
      <FreeMusicRecommendResult>[];
  final List<Object> recommendErrors = <Object>[];

  @override
  Future<FreeMusicSearchResult> searchSongs(
    String query, {
    int page = 0,
    List<String>? sources,
  }) {
    final _SearchCall call = _SearchCall(
      query: query,
      page: page,
      sources: sources,
    );
    searchCalls.add(call);
    final Future<FreeMusicSearchResult> Function(_SearchCall call)? handler =
        onSearch;
    if (handler != null) {
      return handler(call);
    }
    if (searchErrors.isNotEmpty) {
      return Future<FreeMusicSearchResult>.error(searchErrors.removeAt(0));
    }
    return Future<FreeMusicSearchResult>.value(searchResults.removeAt(0));
  }

  @override
  Future<FreeMusicRecommendResult> fetchRecommendations({
    List<String>? sources,
  }) {
    recommendCalls.add(sources);
    if (recommendErrors.isNotEmpty) {
      return Future<FreeMusicRecommendResult>.error(
        recommendErrors.removeAt(0),
      );
    }
    return Future<FreeMusicRecommendResult>.value(recommendResults.removeAt(0));
  }
}

class _SearchCall {
  const _SearchCall({
    required this.query,
    required this.page,
    required this.sources,
  });

  final String query;
  final int page;
  final List<String>? sources;
}

FreeMusicSong _song(String id) {
  return FreeMusicSong(
    id: id,
    source: 'kuwo',
    name: 'Song $id',
    artist: 'Artist',
    duration: 120,
  );
}

FreeMusicPlaylist _playlist(String id) {
  return FreeMusicPlaylist(id: id, source: 'netease', name: 'Playlist $id');
}
