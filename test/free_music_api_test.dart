import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
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

  test('FreeMusicApi fetches recommended playlists', () async {
    late Uri requestedUri;
    final FreeMusicApi api = FreeMusicApi(
      baseUri: 'https://music.sy110.eu.org/api/v1/freemusic',
      client: MockClient((http.Request request) async {
        requestedUri = request.url;
        return http.Response(
          '''
          {
            "playlists": [
              {
                "id": "867916143",
                "source": "netease",
                "name": "中文说唱Flow",
                "cover": "https://example.com/playlist.jpg",
                "creator": "网易云推荐",
                "description": "精选歌单",
                "track_count": 647,
                "play_count": 20872758,
                "link": "https://example.com/playlist"
              }
            ]
          }
          ''',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final FreeMusicRecommendResult result = await api.fetchRecommendations(
      sources: <String>['netease', 'kuwo'],
    );

    expect(requestedUri.path, '/api/v1/freemusic/recommend');
    expect(requestedUri.queryParameters['sources'], 'netease,kuwo');
    expect(result.playlists, hasLength(1));
    expect(result.playlists.single.id, '867916143');
    expect(result.playlists.single.source, 'netease');
    expect(result.playlists.single.name, '中文说唱Flow');
    expect(result.playlists.single.cover, 'https://example.com/playlist.jpg');
    expect(result.playlists.single.creator, '网易云推荐');
    expect(result.playlists.single.trackCount, 647);
    expect(result.playlists.single.playCount, 20872758);
  });

  test('FreeMusicApi fetches playlist song pages', () async {
    late Uri requestedUri;
    final FreeMusicApi api = FreeMusicApi(
      baseUri: 'https://music.sy110.eu.org/api/v1/freemusic',
      client: MockClient((http.Request request) async {
        requestedUri = request.url;
        return http.Response(
          '''
          {
            "total": 17,
            "songs": [
              {
                "id": "228429",
                "source": "kuwo",
                "name": "好心分手",
                "artist": "卢巧音&王力宏",
                "album": "男女情歌对唱冠军全记录",
                "duration": 182,
                "cover": "https://example.com/song.jpg"
              }
            ]
          }
          ''',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final FreeMusicPlaylistPage page = await api.fetchPlaylistSongs(
      const FreeMusicPlaylist(
        id: '1012368062',
        source: 'kuwo',
        name: '好听的粤语对唱',
      ),
      offset: 30,
      size: 15,
    );

    expect(requestedUri.path, '/api/v1/freemusic/playlist/page');
    expect(requestedUri.queryParameters['id'], '1012368062');
    expect(requestedUri.queryParameters['source'], 'kuwo');
    expect(requestedUri.queryParameters['offset'], '30');
    expect(requestedUri.queryParameters['size'], '15');
    expect(page.total, 17);
    expect(page.songs, hasLength(1));
    expect(page.songs.single.name, '好心分手');
    expect(page.songs.single.album, '男女情歌对唱冠军全记录');
    expect(page.songs.single.cover, 'https://example.com/song.jpg');
  });

  test(
    'FreeMusicApi returns empty playlist page for incomplete playlists',
    () async {
      final FreeMusicApi api = FreeMusicApi(
        client: MockClient((http.Request request) async {
          fail('Request should not be sent for incomplete playlists');
        }),
      );

      final FreeMusicPlaylistPage page = await api.fetchPlaylistSongs(
        const FreeMusicPlaylist(id: '', source: '', name: ''),
      );

      expect(page.songs, isEmpty);
      expect(page.total, 0);
    },
  );

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

  test('FreeMusicApi fetches and parses synced lyrics', () async {
    late Uri requestedUri;
    late Map<String, String> requestedHeaders;
    final FreeMusicApi api = FreeMusicApi(
      baseUri: 'https://music.sy110.eu.org/api/v1/freemusic',
      client: MockClient((http.Request request) async {
        requestedUri = request.url;
        requestedHeaders = request.headers;
        return http.Response.bytes(
          utf8.encode('[00:01.50]第一句\n[00:03][00:04.25]第二句'),
          200,
          headers: <String, String>{
            'content-type': 'text/plain; charset=utf-8',
          },
        );
      }),
    );

    final FreeMusicLyrics lyrics = await api.fetchLyrics(
      const FreeMusicSong(
        id: '228908',
        source: 'kuwo',
        name: '晴天',
        artist: '周杰伦',
        duration: 269,
      ),
    );

    expect(requestedUri.path, '/api/v1/freemusic/lyric');
    expect(requestedUri.queryParameters['id'], '228908');
    expect(requestedUri.queryParameters['source'], 'kuwo');
    expect(requestedUri.queryParameters['name'], '晴天');
    expect(requestedUri.queryParameters['artist'], '周杰伦');
    expect(requestedHeaders['Referer'], 'https://music.sy110.eu.org/music');
    expect(lyrics.raw, contains('第一句'));
    expect(lyrics.lines, hasLength(3));
    expect(lyrics.lines.first.time, const Duration(milliseconds: 1500));
    expect(lyrics.lines.first.text, '第一句');
    expect(lyrics.lines.last.time, const Duration(milliseconds: 4250));
    expect(lyrics.lines.last.text, '第二句');
  });

  test('FreeMusicApi returns empty lyrics for incomplete songs', () async {
    final FreeMusicApi api = FreeMusicApi(
      client: MockClient((http.Request request) async {
        fail('Request should not be sent for incomplete songs');
      }),
    );

    final FreeMusicLyrics lyrics = await api.fetchLyrics(
      const FreeMusicSong(
        id: '',
        source: '',
        name: '',
        artist: '',
        duration: 0,
      ),
    );

    expect(lyrics.isEmpty, isTrue);
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
