import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/controllers/music_search_controller.dart';
import 'package:music_car_app/free_music_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('recommendations serve cache until forceRefresh', () async {
    final _CountingClient client = _CountingClient();
    final MusicSearchController controller = MusicSearchController(
      client: client,
      preferencesLoader: SharedPreferences.getInstance,
    );

    await controller.loadRecommendations(sources: <String>['netease']);
    expect(client.calls, 1);
    expect(controller.recommendedPlaylists, hasLength(1));

    await controller.loadRecommendations(sources: <String>['netease']);
    expect(client.calls, 1);

    await controller.loadRecommendations(
      sources: <String>['netease'],
      forceRefresh: true,
    );
    expect(client.calls, 2);

    controller.dispose();
  });

  test('source switch publishes cached catalog without forceRefresh', () async {
    final _CountingClient client = _CountingClient();
    final MusicSearchController controller = MusicSearchController(
      client: client,
      preferencesLoader: SharedPreferences.getInstance,
    );

    await controller.loadRecommendations(sources: <String>['netease']);
    await controller.loadRecommendations(sources: <String>['kugou']);
    expect(client.calls, 2);
    expect(controller.recommendedPlaylists.single.source, 'kugou');

    await controller.loadRecommendations(sources: <String>['netease']);
    expect(client.calls, 2);
    expect(controller.recommendedPlaylists.single.source, 'netease');
    expect(controller.lastRecommendationSourceKey, 'netease');

    controller.dispose();
  });
}

class _CountingClient implements MusicSearchClient {
  int calls = 0;

  @override
  Future<FreeMusicRecommendResult> fetchRecommendations({
    List<String>? sources,
  }) async {
    calls += 1;
    final String source =
        (sources == null || sources.isEmpty) ? 'netease' : sources.first;
    return FreeMusicRecommendResult(
      playlists: <FreeMusicPlaylist>[
        FreeMusicPlaylist(
          id: 'p1',
          source: source,
          name: 'Demo $source',
        ),
      ],
    );
  }

  @override
  Future<FreeMusicSearchResult> searchSongs(
    String query, {
    int page = 0,
    List<String>? sources,
  }) async {
    return const FreeMusicSearchResult(
      songs: <FreeMusicSong>[],
      hasMore: false,
      page: 0,
    );
  }
}
