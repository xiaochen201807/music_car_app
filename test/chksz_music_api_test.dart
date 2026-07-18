import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_car_app/free_music_api.dart';
import 'package:music_car_app/services/chksz_music_api.dart';

void main() {
  MockClient mockClient(Map<String, http.Response Function(http.Request)> handlers) {
    return MockClient((http.Request request) async {
      for (final MapEntry<String, http.Response Function(http.Request)> entry
          in handlers.entries) {
        if (request.url.path.contains(entry.key)) {
          return entry.value(request);
        }
      }
      return http.Response('Not Found', 404);
    });
  }

  test('maps preferred bitrate to ChKSz netease levels', () {
    expect(ChkSzMusicApi.mapBitrateToLevel('320kmp3'), 'exhigh');
    expect(ChkSzMusicApi.mapBitrateToLevel('128kmp3'), 'standard');
    expect(ChkSzMusicApi.mapBitrateToLevel('flac'), 'lossless');
    expect(ChkSzMusicApi.mapBitrateToLevel('hires'), 'hires');
    expect(ChkSzMusicApi.mapBitrateToLevel('jymaster'), 'jymaster');
    expect(ChkSzMusicApi.mapBitrateToLevel('48kaac'), 'standard');
  });

  test('searches netease songs via 163_search', () async {
    late Uri requested;
    final ChkSzMusicApi api = ChkSzMusicApi(
      baseUri: 'https://api.chksz.com',
      client: mockClient(<String, http.Response Function(http.Request)>{
        '163_search': (http.Request request) {
          requested = request.url;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'code': 200,
              'msg': 'success',
              'data': <String, dynamic>{
                'songs': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 2652820720,
                    'name': '晴天',
                    'artists': '周杰伦',
                    'album': '叶惠美',
                    'picUrl': 'https://example.com/cover.jpg',
                    'duration': 269000,
                  },
                ],
                'total': 1,
              },
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        },
      }),
    );

    final FreeMusicSearchResult result = await api.searchSongs(
      '晴天',
      source: 'netease',
    );

    expect(requested.path, '/api/163_search');
    expect(requested.queryParameters['keyword'], '晴天');
    expect(result.songs, hasLength(1));
    expect(result.songs.first.id, '2652820720');
    expect(result.songs.first.source, 'netease');
    expect(result.songs.first.artist, '周杰伦');
    expect(result.songs.first.duration, 269);
    expect(result.hasMore, isFalse);
  });

  test('resolves netease url with quality fallback ladder', () async {
    final List<String> levels = <String>[];
    final ChkSzMusicApi api = ChkSzMusicApi(
      client: mockClient(<String, http.Response Function(http.Request)>{
        '163_music': (http.Request request) {
          final String level = request.url.queryParameters['level'] ?? '';
          levels.add(level);
          if (level == 'jymaster') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'code': 404,
                'msg': 'Music URL not found',
              }),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode(<String, dynamic>{
              'code': 200,
              'msg': 'success',
              'data': <String, dynamic>{
                'id': 1,
                'url': 'https://cdn.example.com/song.mp3',
                'level': level,
                'name': '晴天',
                'artist': '周杰伦',
              },
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        },
      }),
    );

    final FreeMusicResolvedUrl? resolved = await api.resolveSongUrl(
      const FreeMusicSong(
        id: '1',
        source: 'netease',
        name: '晴天',
        artist: '周杰伦',
        duration: 269,
      ),
      bitrate: 'jymaster',
    );

    expect(levels.first, 'jymaster');
    expect(levels, contains('exhigh'));
    expect(resolved?.url, 'https://cdn.example.com/song.mp3');
    expect(resolved?.source, 'netease');
  });

  test('resolves qq music by mid', () async {
    late Uri requested;
    final ChkSzMusicApi api = ChkSzMusicApi(
      client: mockClient(<String, http.Response Function(http.Request)>{
        'qq_music': (http.Request request) {
          requested = request.url;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'name': '晴天',
              'id': '0039MnYb0qxYhV',
              'url': 'https://stream.qq.com/song.m4a',
              'duration': 269,
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        },
      }),
    );

    final FreeMusicResolvedUrl? resolved = await api.resolveSongUrl(
      const FreeMusicSong(
        id: '0039MnYb0qxYhV',
        source: 'qq',
        name: '晴天',
        artist: '周杰伦',
        duration: 269,
      ),
    );

    expect(requested.queryParameters['mid'], '0039MnYb0qxYhV');
    expect(resolved?.url, 'https://stream.qq.com/song.m4a');
    expect(resolved?.source, 'qq');
  });

  test('resolves kugou music by id and parses lyrics', () async {
    final ChkSzMusicApi api = ChkSzMusicApi(
      client: mockClient(<String, http.Response Function(http.Request)>{
        'kugou_music': (http.Request request) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'code': 200,
              'msg': 'ok',
              'data': <String, dynamic>{
                'songName': '晴天',
                'singerName': '周杰伦',
                'url': 'https://fs.kugou.com/song.flac',
                'lyrics': '[00:29.26]故事的小黄花\n[00:32.71]从出生那年就飘着',
              },
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        },
      }),
    );

    final FreeMusicResolvedUrl? resolved = await api.resolveSongUrl(
      const FreeMusicSong(
        id: 'B3A52A7A',
        source: 'kugou',
        name: '晴天',
        artist: '周杰伦',
        duration: 269,
      ),
    );
    final FreeMusicLyrics lyrics = await api.fetchLyrics(
      const FreeMusicSong(
        id: 'B3A52A7A',
        source: 'kugou',
        name: '晴天',
        artist: '周杰伦',
        duration: 269,
      ),
    );

    expect(resolved?.url, 'https://fs.kugou.com/song.flac');
    expect(lyrics.raw, contains('故事的小黄花'));
    expect(lyrics.lines, isNotEmpty);
    expect(lyrics.lines.first.text, '故事的小黄花');
  });

  test('matches a song on another ChKSz-supported source', () async {
    final ChkSzMusicApi api = ChkSzMusicApi(
      client: mockClient(<String, http.Response Function(http.Request)>{
        '163_search': (http.Request request) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'code': 200,
              'data': <String, dynamic>{
                'songs': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 1001,
                    'name': '晴天',
                    'artists': '周杰伦',
                    'album': '叶惠美',
                    'duration': 269000,
                  },
                  <String, dynamic>{
                    'id': 1002,
                    'name': '晴天(翻唱)',
                    'artists': '路人甲',
                    'album': '翻唱',
                    'duration': 200000,
                  },
                ],
                'total': 2,
              },
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        },
      }),
    );

    final FreeMusicSourceSwitch? matched = await api.matchSong(
      const FreeMusicSong(
        id: 'kw-1',
        source: 'kuwo',
        name: '晴天',
        artist: '周杰伦',
        duration: 269,
      ),
      target: 'netease',
    );

    expect(matched, isNotNull);
    expect(matched!.song.id, '1001');
    expect(matched.song.source, 'netease');
    expect(matched.score, greaterThanOrEqualTo(0.5));
  });

  test('loads netease playlist tracks with offset/limit', () async {
    final ChkSzMusicApi api = ChkSzMusicApi(
      client: mockClient(<String, http.Response Function(http.Request)>{
        '163_playlist': (http.Request request) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'data': <String, dynamic>{
                'id': 1,
                'name': '榜单',
                'trackCount': 3,
                'tracks': <Map<String, dynamic>>[
                  for (int i = 1; i <= 3; i++)
                    <String, dynamic>{
                      'id': i,
                      'name': '曲目$i',
                      'ar': <Map<String, dynamic>>[
                        <String, dynamic>{'name': '歌手$i'},
                      ],
                      'al': <String, dynamic>{
                        'name': '专辑$i',
                        'picUrl': 'https://example.com/$i.jpg',
                      },
                    },
                ],
              },
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        },
      }),
    );

    final FreeMusicPlaylistPage page = await api.fetchPlaylistSongs(
      const FreeMusicPlaylist(id: '1', source: 'netease', name: '榜单'),
      offset: 1,
      size: 1,
    );

    expect(page.total, 3);
    expect(page.songs, hasLength(1));
    expect(page.songs.single.name, '曲目2');
    expect(page.songs.single.source, 'netease');
  });
}
