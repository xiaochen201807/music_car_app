import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_car_app/free_music_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    // 初始化 SharedPreferences 用于测试
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // Helper function to create a mock client that handles auth and API requests
  MockClient createMockClient(Map<String, http.Response Function(http.Request)> handlers) {
    return MockClient((http.Request request) async {
      final String path = request.url.path;

      // Mock login endpoint
      if (path == '/api/v1/auth/login') {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'code': 0,
            'message': '登录成功',
            'data': <String, dynamic>{
              'access_token': 'mock_access_token',
              'refresh_token': 'mock_refresh_token',
              'expires_in': 7200,
            },
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }

      // Route to specific handlers
      for (final MapEntry<String, http.Response Function(http.Request)> entry in handlers.entries) {
        if (path.contains(entry.key)) {
          return entry.value(request);
        }
      }

      return http.Response('Not Found', 404);
    });
  }

  test('FreeMusicApi fetches source metadata', () async {
    final FreeMusicApi api = FreeMusicApi(
      baseUri: 'https://music.sy110.eu.org',
      client: createMockClient(<String, http.Response Function(http.Request)>{}),
    );

    final FreeMusicSources sources = await api.fetchSources();

    expect(sources.allSources, <String>['kuwo', 'netease', 'qq', 'kugou']);
    expect(sources.defaultSources, <String>['kuwo', 'netease']);
    expect(sources.activeSources, <String>['kuwo', 'netease']);
    expect(sources.labelFor('kuwo'), '酷我音乐');
    expect(sources.labelFor('netease'), '网易云音乐');
  });

  test('FreeMusicApi fetches hot search keywords (returns empty)', () async {
    final FreeMusicApi api = FreeMusicApi(
      client: createMockClient(<String, http.Response Function(http.Request)>{}),
    );

    final List<String> keywords = await api.fetchHotSearchKeywords();

    // sy110 暂无热搜接口
    expect(keywords, isEmpty);
  });

  test('FreeMusicApi searches songs with sy110 API format', () async {
    late Uri requestedUri;
    late Map<String, String> requestedHeaders;
    final FreeMusicApi api = FreeMusicApi(
      baseUri: 'https://music.sy110.eu.org',
      client: createMockClient(<String, http.Response Function(http.Request)>{
        'search/songs': (http.Request request) {
          requestedUri = request.url;
          requestedHeaders = request.headers;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'code': 0,
              'message': 'success',
              'data': <String, dynamic>{
                'list': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': '228908',
                    'source': 'kuwo',
                    'name': '晴天',
                    'artists': <Map<String, dynamic>>[
                      <String, dynamic>{'name': '周杰伦'},
                    ],
                    'album': <String, dynamic>{
                      'name': '叶惠美',
                      'cover': 'https://example.com/cover.jpg',
                    },
                    'durationMs': 269000,
                    'cover': 'https://example.com/cover.jpg',
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

    final FreeMusicSearchResult result = await api.searchSongs(
      ' 晴天 ',
      sources: <String>['kuwo'],
    );

    expect(requestedUri.path, '/api/music/search/songs');
    expect(requestedUri.queryParameters['q'], '晴天');
    expect(requestedUri.queryParameters['source'], 'kuwo');
    expect(requestedUri.queryParameters['page'], '1');
    expect(requestedUri.queryParameters['page_size'], '20');
    expect(requestedHeaders['Cookie'], contains('access_token'));
    expect(result.songs, hasLength(1));
    expect(result.songs.single.name, '晴天');
    expect(result.songs.single.artist, '周杰伦');
    expect(result.songs.single.album, '叶惠美');
    expect(result.songs.single.cover, 'https://example.com/cover.jpg');
    expect(result.songs.single.duration, 269);
  });

  test('FreeMusicApi returns empty search result for blank query', () async {
    final FreeMusicApi api = FreeMusicApi(
      client: createMockClient(<String, http.Response Function(http.Request)>{
        'search/songs': (http.Request request) {
          fail('Request should not be sent for blank search queries');
        },
      }),
    );

    final FreeMusicSearchResult result = await api.searchSongs('   ');

    expect(result.songs, isEmpty);
    expect(result.hasMore, isFalse);
    expect(result.page, 0);
  });

  test('FreeMusicApi fetches recommended playlists from categories', () async {
    late Uri requestedUri;
    final FreeMusicApi api = FreeMusicApi(
      baseUri: 'https://music.sy110.eu.org',
      client: createMockClient(<String, http.Response Function(http.Request)>{
        'playlists/category': (http.Request request) {
          requestedUri = request.url;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'code': 0,
              'message': 'success',
              'data': <String, dynamic>{
                'list': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': '636158',
                    'source': 'kugou',
                    'name': '抖音歌曲最火的歌',
                    'cover': 'https://example.com/playlist.jpg',
                    'creator': '泪已成海',
                    'description': '精选歌单',
                    'trackCount': 505,
                    'playCount': 4294967295,
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

    final FreeMusicRecommendResult result = await api.fetchRecommendations(
      sources: <String>['kugou'],
    );

    expect(requestedUri.path, '/api/music/playlists/category/kugou/%E5%85%A8%E9%83%A8');
    expect(result.playlists, hasLength(1));
    expect(result.playlists.single.id, '636158');
    expect(result.playlists.single.source, 'kugou');
    expect(result.playlists.single.name, '抖音歌曲最火的歌');
    expect(result.playlists.single.trackCount, 505);
  });

  test('FreeMusicApi fetches playlist song pages', () async {
    late Uri requestedUri;
    final FreeMusicApi api = FreeMusicApi(
      baseUri: 'https://music.sy110.eu.org',
      client: createMockClient(<String, http.Response Function(http.Request)>{
        'playlists/songs': (http.Request request) {
          requestedUri = request.url;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'code': 0,
              'message': 'success',
              'data': <String, dynamic>{
                'list': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': '228429',
                    'source': 'kuwo',
                    'name': '好心分手',
                    'artists': <Map<String, dynamic>>[
                      <String, dynamic>{'name': '卢巧音'},
                      <String, dynamic>{'name': '王力宏'},
                    ],
                    'album': <String, dynamic>{
                      'name': '男女情歌对唱冠军全记录',
                      'cover': 'https://example.com/song.jpg',
                    },
                    'durationMs': 182000,
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
      const FreeMusicPlaylist(
        id: '1012368062',
        source: 'kuwo',
        name: '好听的粤语对唱',
      ),
      offset: 30,
      size: 15,
    );

    expect(requestedUri.path, '/api/music/playlists/songs/kuwo/1012368062');
    expect(requestedUri.queryParameters['page'], '3'); // (30/15)+1
    expect(requestedUri.queryParameters['page_size'], '15');
    expect(page.songs, hasLength(1));
    expect(page.songs.single.name, '好心分手');
    expect(page.songs.single.artist, '卢巧音/王力宏');
  });

  test('FreeMusicApi returns empty playlist page for incomplete playlists', () async {
    final FreeMusicApi api = FreeMusicApi(
      client: createMockClient(<String, http.Response Function(http.Request)>{
        'playlists/songs': (http.Request request) {
          fail('Request should not be sent for incomplete playlists');
        },
      }),
    );

    final FreeMusicPlaylistPage page = await api.fetchPlaylistSongs(
      const FreeMusicPlaylist(id: '', source: '', name: ''),
    );

    expect(page.songs, isEmpty);
    expect(page.total, 0);
  });

  test('FreeMusicApi resolves song_url with sy110 API format', () async {
    late Uri requestedUri;
    final FreeMusicApi api = FreeMusicApi(
      baseUri: 'https://music.sy110.eu.org',
      client: createMockClient(<String, http.Response Function(http.Request)>{
        'songs/url': (http.Request request) {
          requestedUri = request.url;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'code': 0,
              'message': 'success',
              'data': <String, dynamic>{
                'url': 'https://example.com/song.mp3',
                'playable': true,
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
        id: '228908',
        source: 'kuwo',
        name: '晴天',
        artist: '周杰伦',
        duration: 269,
      ),
    );

    expect(requestedUri.path, '/api/music/songs/url/kuwo/228908');
    expect(requestedUri.queryParameters['name'], '晴天');
    expect(requestedUri.queryParameters['artist'], '周杰伦');
    expect(requestedUri.queryParameters['duration_ms'], '269000');
    expect(resolved?.url, 'https://example.com/song.mp3');
    expect(resolved?.source, 'kuwo');
    expect(resolved?.direct, isTrue);
  });

  test('FreeMusicApi fetches lyrics with word timestamps', () async {
    late Uri requestedUri;
    final FreeMusicApi api = FreeMusicApi(
      baseUri: 'https://music.sy110.eu.org',
      client: createMockClient(<String, http.Response Function(http.Request)>{
        'lyrics/discover': (http.Request request) {
          requestedUri = request.url;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'code': 0,
              'message': 'success',
              'data': <String, dynamic>{
                'selected': <String, dynamic>{
                  'raw': '[00:01.500]第一句\n[00:04.250]第二句',
                  'lines': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'startMs': 1500,
                      'endMs': 4250,
                      'text': '第一句',
                      'words': <Map<String, dynamic>>[
                        <String, dynamic>{
                          'startMs': 1500,
                          'endMs': 2000,
                          'text': '第',
                        },
                        <String, dynamic>{
                          'startMs': 2000,
                          'endMs': 2500,
                          'text': '一',
                        },
                        <String, dynamic>{
                          'startMs': 2500,
                          'endMs': 3000,
                          'text': '句',
                        },
                      ],
                    },
                    <String, dynamic>{
                      'startMs': 4250,
                      'endMs': 7000,
                      'text': '第二句',
                    },
                  ],
                },
              },
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        },
      }),
    );

    final FreeMusicLyrics lyrics = await api.fetchEnhancedLyrics(
      const FreeMusicSong(
        id: '228908',
        source: 'kuwo',
        name: '晴天',
        artist: '周杰伦',
        duration: 269,
      ),
    );

    expect(requestedUri.path, '/api/music/lyrics/discover');
    expect(requestedUri.queryParameters['id'], '228908');
    expect(requestedUri.queryParameters['source'], 'kuwo');
    expect(requestedUri.queryParameters['need_word'], 'true');
    expect(lyrics.raw, contains('第一句'));
    expect(lyrics.lines, hasLength(2));
    expect(lyrics.lines.first.time, const Duration(milliseconds: 1500));
    expect(lyrics.lines.first.text, '第一句');
    expect(lyrics.lines.first.words, hasLength(3));
    expect(lyrics.lines.first.words!.first.text, '第');
    expect(lyrics.hasWordTimestamps, isTrue);
  });

  test('FreeMusicApi returns empty lyrics for incomplete songs', () async {
    final FreeMusicApi api = FreeMusicApi(
      client: createMockClient(<String, http.Response Function(http.Request)>{
        'lyrics/discover': (http.Request request) {
          fail('Request should not be sent for incomplete songs');
        },
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
      client: createMockClient(<String, http.Response Function(http.Request)>{
        'songs/url': (http.Request request) {
          fail('Request should not be sent for incomplete songs');
        },
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

  test('FreeMusicApi fetches charts', () async {
    final FreeMusicApi api = FreeMusicApi(
      baseUri: 'https://music.sy110.eu.org',
      client: createMockClient(<String, http.Response Function(http.Request)>{
        'charts': (http.Request request) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'code': 0,
              'message': 'success',
              'data': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': '16',
                  'source': 'kuwo',
                  'name': '酷我热歌榜',
                  'description': '今日更新',
                  'cover': 'https://example.com/chart.jpg',
                  'group': '官方',
                  'official': true,
                },
              ],
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        },
      }),
    );

    final List<FreeMusicChart> charts = await api.fetchCharts(source: 'kuwo');

    expect(charts, hasLength(1));
    expect(charts.single.name, '酷我热歌榜');
    expect(charts.single.official, isTrue);
  });

  test('FreeMusicApi fetches playlist categories', () async {
    final FreeMusicApi api = FreeMusicApi(
      baseUri: 'https://music.sy110.eu.org',
      client: createMockClient(<String, http.Response Function(http.Request)>{
        'playlists/categories': (http.Request request) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'code': 0,
              'message': 'success',
              'data': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': '流行',
                  'name': '流行',
                  'parentId': '风格',
                },
              ],
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        },
      }),
    );

    final List<FreeMusicCategory> categories = await api.fetchPlaylistCategories(source: 'netease');

    expect(categories, hasLength(1));
    expect(categories.single.name, '流行');
  });

  test('FreeMusicApi fetches playlists by category', () async {
    final FreeMusicApi api = FreeMusicApi(
      baseUri: 'https://music.sy110.eu.org',
      client: createMockClient(<String, http.Response Function(http.Request)>{
        'playlists/category': (http.Request request) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'code': 0,
              'message': 'success',
              'data': <String, dynamic>{
                'list': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': '636158',
                    'source': 'kugou',
                    'name': '测试歌单',
                    'cover': 'https://example.com/playlist.jpg',
                    'creator': '创建者',
                    'description': '描述',
                    'trackCount': 100,
                    'playCount': 1000,
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

    final List<FreeMusicPlaylist> playlists = await api.fetchPlaylistsByCategory(
      source: 'kugou',
      categoryId: '全部',
      page: 1,
      pageSize: 20,
    );

    expect(playlists, hasLength(1));
    expect(playlists.single.name, '测试歌单');
  });

  test('FreeMusicApi adds song to favorites', () async {
    bool requestMade = false;
    final FreeMusicApi api = FreeMusicApi(
      baseUri: 'https://music.sy110.eu.org',
      client: createMockClient(<String, http.Response Function(http.Request)>{
        'music/favorites': (http.Request request) {
          requestMade = true;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'code': 0,
              'message': 'success',
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        },
      }),
    );

    final bool success = await api.addToFavorites(
      const FreeMusicSong(
        id: '228908',
        source: 'kuwo',
        name: '晴天',
        artist: '周杰伦',
        duration: 269,
      ),
    );

    expect(requestMade, isTrue);
    expect(success, isTrue);
  });

  test('FreeMusicApi adds recent play', () async {
    bool requestMade = false;
    final FreeMusicApi api = FreeMusicApi(
      baseUri: 'https://music.sy110.eu.org',
      client: createMockClient(<String, http.Response Function(http.Request)>{
        'recent_plays': (http.Request request) {
          requestMade = true;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'code': 0,
              'message': 'success',
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        },
      }),
    );

    final bool success = await api.addRecentPlay(
      const FreeMusicSong(
        id: '228908',
        source: 'kuwo',
        name: '晴天',
        artist: '周杰伦',
        duration: 269,
      ),
    );

    expect(requestMade, isTrue);
    expect(success, isTrue);
  });
}
