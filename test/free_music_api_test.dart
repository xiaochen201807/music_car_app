import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_car_app/free_music_api.dart';

void main() {
  test('FreeMusicApi searches songs with expected query parameters', () async {
    late Uri requestedUri;
    late Map<String, String> requestedHeaders;
    final FreeMusicApi api = FreeMusicApi(
      baseUri: 'https://music.sy110.eu.org/api/v1/freemusic',
      client: MockClient((http.Request request) async {
        requestedUri = request.url;
        requestedHeaders = request.headers;
        return http.Response(
          '''
          {
            "hasMore": true,
            "page": 0,
            "songs": [
              {
                "id": "228908",
                "source": "kuwo",
                "name": "晴天",
                "artist": "周杰伦",
                "duration": 269,
                "album": "叶惠美",
                "cover": "https://example.com/cover.jpg"
              }
            ]
          }
          ''',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final FreeMusicSearchResult result = await api.searchSongs(
      ' 晴天 ',
      sources: <String>['kuwo', 'netease'],
    );

    expect(requestedUri.path, '/api/v1/freemusic/search');
    expect(requestedUri.queryParameters['q'], '晴天');
    expect(requestedUri.queryParameters['type'], 'song');
    expect(requestedUri.queryParameters['page'], '0');
    expect(requestedUri.queryParameters['sources'], 'kuwo,netease');
    expect(requestedHeaders['Referer'], 'https://music.sy110.eu.org/music');
    expect(result.hasMore, isTrue);
    expect(result.page, 0);
    expect(result.songs, hasLength(1));
    expect(result.songs.single.name, '晴天');
    expect(result.songs.single.artist, '周杰伦');
    expect(result.songs.single.album, '叶惠美');
    expect(result.songs.single.cover, 'https://example.com/cover.jpg');
  });

  test('FreeMusicApi returns empty search result for blank query', () async {
    final FreeMusicApi api = FreeMusicApi(
      client: MockClient((http.Request request) async {
        fail('Request should not be sent for blank search queries');
      }),
    );

    final FreeMusicSearchResult result = await api.searchSongs('   ');

    expect(result.songs, isEmpty);
    expect(result.hasMore, isFalse);
    expect(result.page, 0);
  });

  test('FreeMusicApi treats null songs as an empty list', () async {
    final FreeMusicApi api = FreeMusicApi(
      client: MockClient((http.Request request) async {
        return http.Response('{"hasMore":false,"page":1,"songs":null}', 200);
      }),
    );

    final FreeMusicSearchResult result = await api.searchSongs('missing');

    expect(result.songs, isEmpty);
    expect(result.hasMore, isFalse);
    expect(result.page, 1);
  });

  test('FreeMusicApi resolves song_url with expected query parameters', () async {
    late Uri requestedUri;
    late Map<String, String> requestedHeaders;
    final FreeMusicApi api = FreeMusicApi(
      baseUri: 'https://music.sy110.eu.org/api/v1/freemusic',
      client: MockClient((http.Request request) async {
        requestedUri = request.url;
        requestedHeaders = request.headers;
        return http.Response(
          '{"direct":true,"source":"kuwo","url":"https://example.com/song.mp3"}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final FreeMusicResolvedUrl? resolved = await api.resolveSongUrl(
      const FreeMusicSong(
        id: '228908',
        source: 'kuwo',
        name: '晴天',
        artist: '周杰伦',
        duration: 269,
      ),
    );

    expect(requestedUri.path, '/api/v1/freemusic/song_url');
    expect(requestedUri.queryParameters['id'], '228908');
    expect(requestedUri.queryParameters['source'], 'kuwo');
    expect(requestedUri.queryParameters['name'], '晴天');
    expect(requestedUri.queryParameters['artist'], '周杰伦');
    expect(requestedUri.queryParameters['duration'], '269');
    expect(requestedUri.queryParameters['br'], '320kmp3');
    expect(requestedHeaders['Referer'], 'https://music.sy110.eu.org/music');
    expect(resolved?.url, 'https://example.com/song.mp3');
    expect(resolved?.source, 'kuwo');
    expect(resolved?.direct, isTrue);
  });

  test('FreeMusicApi returns null when song cannot be resolved', () async {
    final FreeMusicApi api = FreeMusicApi(
      client: MockClient((http.Request request) async {
        fail('Request should not be sent for incomplete songs');
      }),
    );

    final FreeMusicResolvedUrl? resolved = await api.resolveSongUrl(
      const FreeMusicSong(
        id: '',
        source: '',
        name: '',
        artist: '',
        duration: 0,
      ),
    );

    expect(resolved, isNull);
  });
}
